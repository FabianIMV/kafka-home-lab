# Lab de Kafka + Kubernetes (práctica local)

Este lab levanta **dos clusters de Kubernetes locales** (`kafka-dev` y `kafka-prod`, vía [kind](https://kind.sigs.k8s.io/)) con Kafka corriendo adentro (vía [Strimzi](https://strimzi.io/), el operador de Kafka para k8s más usado en el mundo real). Un productor queda generando mensajes 24/7 y un consumidor deliberadamente lento los va leyendo, para que puedas ver **offsets, particiones y consumer lag moviéndose en vivo**, y de paso memorizar `kubectl` — incluyendo cambio de **contexto**, que es lo que más se parece a lo que harías en la pega (ahí normalmente tienes contextos separados para dev/staging/prod).

Todo corre en tu máquina, en contenedores desechables. Puedes romper cosas sin miedo: `./scripts/k8s-05-teardown.sh both` lo destruye todo en segundos y partes de cero.

> ¿Por qué no GitHub Pages? Pages solo sirve archivos estáticos (HTML/CSS/JS). No puede correr un cluster de k8s ni un broker de Kafka — no hay cómputo detrás, es puro hosting de archivos. Para esto necesitas ejecutar algo en tu máquina (o en una VM/cloud), no en Pages.

## 0. Prerrequisitos

Instala en tu PC de pega (o el que uses para practicar):

- **Docker Desktop** (o Docker Engine) corriendo.
- **kind** — https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl** — https://kubernetes.io/docs/tasks/tools/
- (Opcional) **k9s** para navegar el cluster con una TUI — ayuda mucho a memorizar recursos.

Verifica:
```bash
docker info
kind version
kubectl version --client
```

## 1. Arquitectura del lab

```
kind cluster "kafka-dev"  (contexto: kind-kafka-dev)
kind cluster "kafka-prod" (contexto: kind-kafka-prod)

  namespace: kafka-lab
    ├── Strimzi Cluster Operator          (gestiona el CR Kafka)
    ├── KafkaNodePool "dual-role"         (1 nodo: broker + controller, KRaft, sin Zookeeper)
    ├── Kafka "kafka-lab"                 (el cluster de Kafka en si)
    ├── KafkaTopic "lab.orders"   (3 particiones)
    ├── KafkaTopic "lab.payments" (6 particiones)
    ├── Deployment lab-producer            → genera pedidos y pagos sin parar
    ├── Deployment lab-consumer-orders     → los lee, a proposito lento (grupo: lab-consumer-group)
    └── Deployment kafka-ui                → interfaz web (localhost:8080 via port-forward)
```

Cada cluster (`dev`, `prod`) es independiente: mismo namespace y mismos manifiestos, pero distinto contexto de `kubectl`. Esa es la gracia — practicas cambiar de contexto igual que en la pega, no solo namespace.

## 2. Levantar el ambiente `dev`

```bash
# 1. Crea el cluster kind
./scripts/k8s-01-create-clusters.sh dev

# 2. Instala el operador Strimzi
./scripts/k8s-02-install-strimzi.sh dev

# 3. Despliega Kafka (tarda 2-5 min en quedar Ready)
./scripts/k8s-03-deploy-kafka.sh dev

# 4. Despliega productor, consumidor y Kafka UI
./scripts/k8s-04-deploy-workloads.sh dev
```

Verifica que todo esté corriendo:
```bash
./scripts/k8s-lab-status.sh dev pods
```

Mira la UI:
```bash
./scripts/k8s-lab-status.sh dev ui
# abre http://localhost:8080 en el navegador
```

Cuando quieras el ambiente `prod` (para practicar cambio de contexto), repite los mismos 4 comandos cambiando `dev` por `prod`.

## 3. Practicar contextos y namespaces de kubectl

Esto es lo que más se parece a la pega: nunca vas a tener solo un cluster.

```bash
# Ver todos los contextos disponibles
kubectl config get-contexts

# Cambiar el contexto activo (afecta a TODOS los comandos siguientes)
kubectl config use-context kind-kafka-dev
kubectl config use-context kind-kafka-prod

# Ver en qué contexto estás parado ahora mismo (chequealo SIEMPRE antes de borrar algo)
kubectl config current-context

# Ejecutar un comando puntual en un contexto especifico, SIN cambiar el activo
# (esto es lo mas seguro cuando trabajas con prod)
kubectl --context kind-kafka-prod get pods -n kafka-lab

# Fijar un namespace por defecto para un contexto, para no tener que
# escribir -n kafka-lab en cada comando
kubectl config set-context --current --namespace=kafka-lab

# Renombrar un contexto a algo mas corto (útil si en la pega los nombres son largos)
kubectl config rename-context kind-kafka-dev dev
kubectl config rename-context kind-kafka-prod prod
```

**Ejercicio:** crea ambos clusters (`dev` y `prod`), y practica ejecutar el mismo comando (`kubectl get pods -n kafka-lab`) contra los dos usando `--context`, sin nunca cambiar tu contexto activo. Es el hábito más importante para no operar por error contra el cluster equivocado.

## 4. Entendiendo particiones, offsets y consumer lag

Todos los comandos de esta sección usan el script `./scripts/k8s-lab-status.sh <dev|prod> <comando>`.

### 4.1 Particiones

```bash
./scripts/k8s-lab-status.sh dev describe-topic lab.orders
```

Vas a ver 3 particiones (0, 1, 2), cada una con su propio **líder** (el broker que la sirve) y su propio contador de offset independiente. Cada mensaje nuevo en una partición recibe el **siguiente offset** de esa partición — es un contador que solo sube, por partición.

Las claves de los mensajes (`user_id`) determinan a qué partición van: la misma clave siempre cae en la misma partición (por eso, en el productor, verás siempre los mismos `USR_x` yendo al mismo lugar). Así se garantiza orden por clave.

### 4.2 Offsets y lag en vivo

```bash
./scripts/k8s-lab-status.sh dev lag
```

Columnas importantes:
- `CURRENT-OFFSET`: hasta dónde ha leído el consumer group.
- `LOG-END-OFFSET`: el offset más nuevo que existe en la partición (lo último que produjo el productor).
- `LAG`: la diferencia. **Esto es consumer lag** — cuántos mensajes están esperando a ser procesados.

El consumidor del lab (`lab-consumer-orders`) está hecho a propósito para ser lento (lee 5 mensajes y pausa 3 segundos), así que vas a ver el `LAG` subir solo. Déjalo correr 1-2 minutos y vuelve a mirar:

```bash
./scripts/k8s-lab-status.sh dev watch-lag
```

### 4.3 El lag baja al escalar el consumer group

```bash
# Sube a 3 replicas -> se reparten las 3 particiones de lab.orders (1 a 1)
./scripts/k8s-lab-status.sh dev scale-consumer 3
./scripts/k8s-lab-status.sh dev watch-lag
```

Vas a ver un rebalanceo del grupo (Kafka reasigna particiones entre los consumers activos) y el lag bajando más rápido. Como hay 3 particiones, con 4+ replicas la 4ta se queda sin partición que leer (queda "idle") — es un buen ejercicio para entender por qué el número de particiones limita el paralelismo real de un consumer group.

```bash
# Baja a 0 -> nadie consume, el lag crece sin control (el productor sigue corriendo)
./scripts/k8s-lab-status.sh dev scale-consumer 0
./scripts/k8s-lab-status.sh dev watch-lag

# Vuelve a subir y observa cómo el consumer retoma desde el offset donde quedó
# (no relee desde el principio: el offset commiteado quedó guardado en Kafka)
./scripts/k8s-lab-status.sh dev scale-consumer 1
```

## 5. Escenarios de incidentes (para romper cosas sin miedo)

```bash
# Matar el pod del broker y ver la autorecuperación de k8s
./scripts/k8s-lab-status.sh dev kill-broker-pod
kubectl --context kind-kafka-dev -n kafka-lab get pods -w

# Ver logs en vivo del productor / consumidor
./scripts/k8s-lab-status.sh dev logs-producer
./scripts/k8s-lab-status.sh dev logs-consumer

# Practicar cordon/drain de un nodo del cluster (kind trae 2-3 workers)
kubectl --context kind-kafka-dev get nodes
kubectl --context kind-kafka-dev cordon kafka-dev-worker
kubectl --context kind-kafka-dev drain kafka-dev-worker --ignore-daemonsets --delete-emptydir-data
# revierte con:
kubectl --context kind-kafka-dev uncordon kafka-dev-worker
```

## 6. Cheatsheet rápido de kubectl (lo que más vas a teclear)

```bash
kubectl config get-contexts                          # listar contextos
kubectl config use-context <nombre>                   # cambiar contexto activo
kubectl --context <nombre> get pods -n kafka-lab       # comando puntual sin cambiar contexto
kubectl get pods -n kafka-lab -o wide                  # pods + nodo donde corren
kubectl describe pod <pod> -n kafka-lab                # eventos y detalle de un pod
kubectl logs -f deploy/lab-producer -n kafka-lab       # logs en vivo
kubectl exec -it deploy/lab-producer -n kafka-lab -- sh # shell dentro del pod
kubectl scale deployment/lab-consumer-orders --replicas=3 -n kafka-lab
kubectl rollout restart deployment/lab-producer -n kafka-lab
kubectl get kafka,kafkanodepool,kafkatopic -n kafka-lab
kubectl port-forward svc/kafka-ui 8080:8080 -n kafka-lab
```

## 7. Limpieza

```bash
# Borrar solo dev
./scripts/k8s-05-teardown.sh dev

# Borrar todo (dev + prod)
./scripts/k8s-05-teardown.sh both
```

Como todo vive dentro de los contenedores de `kind`, borrar el cluster deja tu máquina limpia — no quedan procesos ni datos sueltos.

## 8. Alternativa sin Kubernetes

Si un día solo quieres un Kafka rápido sin la capa de k8s (para probar un producer/consumer propio, por ejemplo), usa el `docker-compose.yml` de la raíz del repo con `./start-kafka.sh` — ver el `README.md` principal.

#!/bin/bash
# Cheat-sheet ejecutable: comandos que más vas a usar para entender
# particiones, offsets y consumer lag en el lab de k8s + Kafka.
set -euo pipefail

ENV="${1:-dev}"
CMD="${2:-help}"

case "$ENV" in
  dev)  CTX="kind-kafka-dev" ;;
  prod) CTX="kind-kafka-prod" ;;
  *) echo "Uso: $0 {dev|prod} <comando>"; exit 1 ;;
esac

NS="kafka-lab"
BOOTSTRAP="kafka-lab-kafka-bootstrap.kafka-lab.svc:9092"
# Usamos el pod del productor como "cliente" porque siempre está corriendo
# y ya trae las herramientas de Kafka (/opt/kafka/bin).
EXEC="kubectl --context $CTX -n $NS exec -i deploy/lab-producer --"

kx() { kubectl --context "$CTX" -n "$NS" "$@"; }

case "$CMD" in
  contexts)
    kubectl config get-contexts
    ;;

  pods)
    kx get pods -o wide
    ;;

  nodes)
    kubectl --context "$CTX" get nodes -o wide
    ;;

  topics)
    $EXEC /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --list
    ;;

  describe-topic)
    TOPIC="${3:?Uso: $0 <env> describe-topic <nombre-topic>}"
    $EXEC /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$BOOTSTRAP" \
      --describe --topic "$TOPIC"
    ;;

  groups)
    $EXEC /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" --list
    ;;

  lag)
    # La columna LAG es la clave: mensajes producidos - mensajes leidos por el grupo.
    $EXEC /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server "$BOOTSTRAP" \
      --describe --group lab-consumer-group
    ;;

  watch-lag)
    watch -n 3 "kubectl --context $CTX -n $NS exec -i deploy/lab-producer -- \
      /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP \
      --describe --group lab-consumer-group"
    ;;

  scale-consumer)
    N="${3:?Uso: $0 <env> scale-consumer <replicas>}"
    kx scale deployment/lab-consumer-orders --replicas="$N"
    echo "✅ Consumer escalado a $N réplica(s). Mira 'lag' o 'watch-lag' para ver el efecto."
    ;;

  logs-producer)
    kx logs deploy/lab-producer --tail=50 -f
    ;;

  logs-consumer)
    kx logs deploy/lab-consumer-orders --tail=50 -f
    ;;

  kill-broker-pod)
    # Con replicas=1 el nombre es deterministico: kafka-lab-dual-role-0
    POD="kafka-lab-dual-role-0"
    echo "💥 Borrando pod del broker: $POD (observa cómo Strimzi lo recrea)"
    kx delete pod "$POD"
    ;;

  ui)
    echo "Abriendo port-forward a Kafka UI en http://localhost:8080 (Ctrl+C para cortar)"
    kx port-forward svc/kafka-ui 8080:8080
    ;;

  help|*)
    cat <<EOF
Uso: $0 {dev|prod} <comando> [args]

Comandos:
  contexts                    Lista los contextos de kubectl disponibles
  pods                        Pods del namespace kafka-lab
  nodes                       Nodos del cluster kind (para practicar cordon/drain)
  topics                      Lista los topics de Kafka
  describe-topic <topic>      Detalle de particiones/réplicas de un topic
  groups                      Lista los consumer groups
  lag                         Describe el lag del grupo lab-consumer-group
  watch-lag                   Igual que 'lag' pero refrescando cada 3s
  scale-consumer <n>          Escala el Deployment del consumidor (para ver el lag bajar/subir)
  logs-producer                Logs en vivo del productor
  logs-consumer                Logs en vivo del consumidor
  kill-broker-pod              Borra el pod del broker para ver la autorecuperación
  ui                           Port-forward a Kafka UI (http://localhost:8080)

Ejemplos:
  $0 dev lag
  $0 dev scale-consumer 3
  $0 dev watch-lag
EOF
    ;;
esac

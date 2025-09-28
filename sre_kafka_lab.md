# 🚀 Laboratorio SRE Kafka - Preparación Banco Falabella

## 🎯 Guía de Inicio Rápido

### ✅ Pre-requisitos
1. **Docker Desktop** instalado y ejecutándose
2. **Python 3** con pip (para el simulador)
3. **Git** para clonar el repo

### 🚀 Pasos para Ejecutar el Lab

#### 1. Preparar el Entorno
```bash
# 1. Asegúrate que Docker esté corriendo
docker info

# 2. Instalar dependencias Python
pip install kafka-python

# 3. Dar permisos de ejecución a scripts
chmod +x *.sh
```

#### 2. Levantar el Cluster
```bash
# Levantar cluster completo (3 brokers + Zookeeper + UI)
docker-compose -f docker-compose-cluster.yml up -d

# Esperar que esté listo (importante!)
sleep 60

# Verificar que todos los contenedores estén corriendo
docker ps
```

#### 3. Crear Topics Bancarios
```bash
# Crear todos los topics necesarios
./create-bank-topics.sh

# Verificar que se crearon correctamente
./sre-commands.sh cluster-health
```

#### 4. Generar Tráfico de Prueba
```bash
# Ejecutar simulador de transacciones bancarias
# Esto generará tráfico por 10 minutos
python3 simulate-bank-traffic.py
```

#### 5. Monitorear Métricas
```bash
# En otra terminal, ejecutar comandos de monitoreo
./sre-commands.sh consumer-lag
./sre-commands.sh performance
./sre-commands.sh topic-partitions
```

### 🔍 Qué Deberías Ver

#### En Kafka UI (http://localhost:8080):
- **Topics activos**: 7 topics bancarios con datos fluyendo
- **Mensajes en tiempo real**: Pagos, alertas de fraude, eventos de usuario
- **Particiones distribuidas**: Entre los 3 brokers
- **Throughput**: ~100-500 msg/segundo según simulación

#### En los Topics:
1. **bank.transactions.payments**
   - Pagos con montos en CLP
   - Status: completed/pending/failed
   - Merchants: FALABELLA, WALMART, etc.

2. **bank.fraud.alerts**
   - Alertas con risk_score > 60
   - Razones: unusual_location, high_amount, etc.
   - Acciones: block/review/notify

3. **bank.users.events**
   - Login/logout de usuarios
   - Cambios de perfil y contraseña
   - Consultas de saldo

#### Métricas Esperadas:
```
✅ Cluster Health: 3/3 brokers activos
✅ Topics: 7 creados con replication factor 3
✅ Throughput: 100-500 mensajes/segundo
✅ Consumer Lag: < 100 mensajes (normal)
✅ Error Rate: < 1%
```

#### Comandos para Verificar:
```bash
# Ver estado general
./sre-commands.sh cluster-health

# Ver lag de consumidores
./sre-commands.sh consumer-lag

# Test de rendimiento
./sre-commands.sh performance

# Ver logs recientes
./sre-commands.sh logs
```

### 🚨 Simular Incidentes (Opcional)
```bash
# Simular caída de broker
./simulate-failures.sh broker-down

# Crear consumer lag artificial
./simulate-failures.sh consumer-lag

# Simular partición de red
./simulate-failures.sh network-partition
```

---

## 📋 Índice Detallado
1. [Cluster Multi-Broker](#cluster-multi-broker)
2. [Simulaciones Bancarias](#simulaciones-bancarias)
3. [Monitoreo con Datadog](#monitoreo-con-datadog)
4. [Escenarios de Incidentes](#escenarios-de-incidentes)
5. [Comandos SRE Críticos](#comandos-sre-críticos)
6. [Métricas y Alertas](#métricas-y-alertas)

## 🏗️ Cluster Multi-Broker

### docker-compose-cluster.yml
```yaml
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    hostname: zookeeper
    container_name: kafka-zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    volumes:
      - zookeeper-data:/var/lib/zookeeper/data
      - zookeeper-logs:/var/lib/zookeeper/log

  kafka1:
    image: confluentinc/cp-kafka:7.5.0
    hostname: kafka1
    container_name: kafka-broker-1
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka1:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'  # Deshabilitado en producción
      KAFKA_DELETE_TOPIC_ENABLE: 'true'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
    volumes:
      - kafka1-data:/var/lib/kafka/data

  kafka2:
    image: confluentinc/cp-kafka:7.5.0
    hostname: kafka2
    container_name: kafka-broker-2
    depends_on:
      - zookeeper
    ports:
      - "9093:9093"
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka2:29093,PLAINTEXT_HOST://localhost:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'
      KAFKA_DELETE_TOPIC_ENABLE: 'true'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
    volumes:
      - kafka2-data:/var/lib/kafka/data

  kafka3:
    image: confluentinc/cp-kafka:7.5.0
    hostname: kafka3
    container_name: kafka-broker-3
    depends_on:
      - zookeeper
    ports:
      - "9094:9094"
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka3:29094,PLAINTEXT_HOST://localhost:9094
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'
      KAFKA_DELETE_TOPIC_ENABLE: 'true'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
    volumes:
      - kafka3-data:/var/lib/kafka/data

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka1
      - kafka2
      - kafka3
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: bank-cluster
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka1:29092,kafka2:29093,kafka3:29094
      KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper:2181
    restart: unless-stopped

  # Datadog Agent
  datadog:
    image: gcr.io/datadoghq/agent:7
    container_name: datadog-agent
    environment:
      - DD_API_KEY=${DD_API_KEY}
      - DD_SITE=datadoghq.com
      - DD_KAFKA_INTEGRATION_ENABLED=true
      - DD_PROCESS_AGENT_ENABLED=true
      - DD_DOCKER_LABELS_AS_TAGS=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
      - ./datadog-conf:/etc/datadog-agent/conf.d
    depends_on:
      - kafka1
      - kafka2
      - kafka3

volumes:
  zookeeper-data:
  zookeeper-logs:
  kafka1-data:
  kafka2-data:
  kafka3-data:
```

## 🏦 Simulaciones Bancarias

### create-bank-topics.sh
```bash
#!/bin/bash

echo "🏦 Creando topics bancarios..."

BOOTSTRAP_SERVERS="localhost:9092,localhost:9093,localhost:9094"

# Topics críticos bancarios
docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.transactions.payments \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 6 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.transactions.transfers \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 6 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.fraud.alerts \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 3 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.users.events \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 4 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.audit.logs \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 8 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.notifications.push \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 4 \
  --replication-factor 3

docker exec kafka-broker-1 kafka-topics --create \
  --topic bank.balance.updates \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 6 \
  --replication-factor 3

echo "✅ Topics bancarios creados"
echo "📋 Listando topics:"
docker exec kafka-broker-1 kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVERS
```

### simulate-bank-traffic.py
```python
#!/usr/bin/env python3

import json
import random
import time
from datetime import datetime
from kafka import KafkaProducer
import uuid

class BankTransactionSimulator:
    def __init__(self):
        self.producer = KafkaProducer(
            bootstrap_servers=['localhost:9092', 'localhost:9093', 'localhost:9094'],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8')
        )
        
    def generate_payment(self):
        return {
            "transaction_id": str(uuid.uuid4()),
            "user_id": f"USR_{random.randint(1000, 9999)}",
            "amount": random.randint(1000, 1000000),
            "currency": "CLP",
            "merchant": random.choice(["FALABELLA", "WALMART", "RIPLEY", "PARIS"]),
            "timestamp": datetime.now().isoformat(),
            "status": random.choice(["completed", "pending", "failed"]),
            "channel": random.choice(["web", "mobile", "atm", "pos"])
        }
    
    def generate_fraud_alert(self):
        return {
            "alert_id": str(uuid.uuid4()),
            "user_id": f"USR_{random.randint(1000, 9999)}",
            "transaction_id": str(uuid.uuid4()),
            "risk_score": random.randint(60, 100),
            "reason": random.choice([
                "unusual_location", "high_amount", "multiple_attempts", 
                "suspicious_merchant", "velocity_check"
            ]),
            "action": random.choice(["block", "review", "notify"]),
            "timestamp": datetime.now().isoformat()
        }
    
    def generate_user_event(self):
        return {
            "event_id": str(uuid.uuid4()),
            "user_id": f"USR_{random.randint(1000, 9999)}",
            "event_type": random.choice([
                "login", "logout", "password_change", "profile_update", 
                "card_activation", "balance_inquiry"
            ]),
            "ip_address": f"192.168.{random.randint(1,255)}.{random.randint(1,255)}",
            "user_agent": "Falabella Mobile App 2.1.0",
            "timestamp": datetime.now().isoformat()
        }
    
    def simulate_traffic(self, duration_seconds=300):
        print(f"🚀 Iniciando simulación por {duration_seconds} segundos...")
        start_time = time.time()
        
        while (time.time() - start_time) < duration_seconds:
            # Pagos (alta frecuencia)
            if random.random() < 0.7:
                payment = self.generate_payment()
                self.producer.send(
                    'bank.transactions.payments',
                    key=payment['user_id'],
                    value=payment
                )
            
            # Fraude (baja frecuencia)
            if random.random() < 0.05:
                fraud = self.generate_fraud_alert()
                self.producer.send(
                    'bank.fraud.alerts',
                    key=fraud['user_id'],
                    value=fraud
                )
            
            # Eventos de usuario (frecuencia media)
            if random.random() < 0.3:
                user_event = self.generate_user_event()
                self.producer.send(
                    'bank.users.events',
                    key=user_event['user_id'],
                    value=user_event
                )
            
            time.sleep(random.uniform(0.1, 2.0))  # Intervalo variable
        
        self.producer.close()
        print("✅ Simulación completada")

if __name__ == "__main__":
    simulator = BankTransactionSimulator()
    simulator.simulate_traffic(600)  # 10 minutos
```

## 📊 Monitoreo con Datadog

### datadog-conf/kafka.yaml
```yaml
init_config:

instances:
  - host: kafka1
    port: 9092
    tags:
      - broker:1
      - env:lab
      - service:kafka

  - host: kafka2
    port: 9093
    tags:
      - broker:2
      - env:lab
      - service:kafka

  - host: kafka3
    port: 9094
    tags:
      - broker:3
      - env:lab
      - service:kafka

# JMX Configuration
  - host: kafka1
    port: 9999
    tags:
      - jmx:kafka1
    user: # JMX user if auth enabled
    password: # JMX password if auth enabled
```

### setup-datadog.sh
```bash
#!/bin/bash

echo "📊 Configurando Datadog para Kafka..."

# Crear directorio de configuración si no existe
mkdir -p datadog-conf

# Crear variable de entorno para API Key
echo "DD_API_KEY=tu_api_key_aqui" > .env

# Configurar JMX en brokers
echo "KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.rmi.port=9999" >> kafka-jmx.env

echo "✅ Configuración de Datadog lista"
echo "📝 Recuerda actualizar tu DD_API_KEY en .env"
```

## 🚨 Escenarios de Incidentes

### simulate-failures.sh
```bash
#!/bin/bash

echo "🚨 Simulador de Incidentes SRE"

case $1 in
  "broker-down")
    echo "🔴 Simulando caída de broker..."
    docker stop kafka-broker-2
    echo "Broker 2 detenido. Observa cómo el cluster se adapta."
    echo "Para recuperar: docker start kafka-broker-2"
    ;;
    
  "consumer-lag")
    echo "🟡 Simulando consumer lag..."
    # Crear un consumer lento
    docker exec -d kafka-broker-1 kafka-console-consumer \
      --topic bank.transactions.payments \
      --bootstrap-server localhost:9092 \
      --group slow-consumer &
    
    # Enviar muchos mensajes rápidamente
    for i in {1..1000}; do
      echo "Mensaje $i" | docker exec -i kafka-broker-1 \
        kafka-console-producer \
        --topic bank.transactions.payments \
        --bootstrap-server localhost:9092
    done
    ;;
    
  "disk-full")
    echo "🔴 Simulando disco lleno..."
    # Crear archivos grandes en el volumen de Kafka
    docker exec kafka-broker-1 dd if=/dev/zero of=/var/lib/kafka/data/testfile bs=1M count=1000
    ;;
    
  "network-partition")
    echo "🔴 Simulando partición de red..."
    # Desconectar un broker de la red
    docker network disconnect kafka-home-lab_default kafka-broker-3
    echo "Broker 3 desconectado. Para reconectar:"
    echo "docker network connect kafka-home-lab_default kafka-broker-3"
    ;;
    
  *)
    echo "Uso: $0 {broker-down|consumer-lag|disk-full|network-partition}"
    ;;
esac
```

## 🛠️ Comandos SRE Críticos

### sre-commands.sh
```bash
#!/bin/bash

BOOTSTRAP_SERVERS="localhost:9092,localhost:9093,localhost:9094"

echo "🔍 Comandos SRE para Kafka"

case $1 in
  "cluster-health")
    echo "🏥 Estado del cluster:"
    docker exec kafka-broker-1 kafka-topics --describe \
      --bootstrap-server $BOOTSTRAP_SERVERS
    ;;
    
  "consumer-groups")
    echo "👥 Grupos de consumidores:"
    docker exec kafka-broker-1 kafka-consumer-groups \
      --bootstrap-server $BOOTSTRAP_SERVERS --list
    ;;
    
  "consumer-lag")
    echo "⏰ Lag de consumidores:"
    docker exec kafka-broker-1 kafka-consumer-groups \
      --bootstrap-server $BOOTSTRAP_SERVERS \
      --describe --all-groups
    ;;
    
  "broker-ids")
    echo "🔢 IDs de brokers:"
    docker exec kafka-broker-1 kafka-metadata-shell \
      --snapshot /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log \
      --print-brokers
    ;;
    
  "topic-partitions")
    echo "📊 Distribución de particiones:"
    for topic in $(docker exec kafka-broker-1 kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVERS); do
      echo "Topic: $topic"
      docker exec kafka-broker-1 kafka-topics --describe \
        --topic $topic --bootstrap-server $BOOTSTRAP_SERVERS
      echo "---"
    done
    ;;
    
  "performance")
    echo "⚡ Test de rendimiento:"
    docker exec kafka-broker-1 kafka-producer-perf-test \
      --topic bank.transactions.payments \
      --num-records 10000 \
      --record-size 1024 \
      --throughput 1000 \
      --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS
    ;;
    
  "logs")
    echo "📜 Logs recientes:"
    docker-compose logs --tail=50 kafka1 kafka2 kafka3
    ;;
    
  *)
    echo "Comandos disponibles:"
    echo "  cluster-health   - Estado general del cluster"
    echo "  consumer-groups  - Lista de grupos de consumidores"
    echo "  consumer-lag     - Lag de todos los grupos"
    echo "  broker-ids       - IDs de brokers activos"
    echo "  topic-partitions - Distribución de particiones"
    echo "  performance      - Test de rendimiento"
    echo "  logs             - Logs recientes"
    ;;
esac
```

## 📈 Métricas y Alertas Críticas

### Métricas Clave para SRE:

1. **Consumer Lag**
   - `kafka.consumer.lag` > 1000 mensajes
   - Indica procesamiento lento

2. **Broker Availability**
   - `kafka.broker.count` < total esperado
   - Brokers caídos

3. **Throughput**
   - `kafka.messages.rate` (mensajes/segundo)
   - `kafka.bytes.rate` (bytes/segundo)

4. **Error Rate**
   - `kafka.errors.rate` > 1%
   - Fallos en producción/consumo

5. **Disk Usage**
   - `kafka.log.size` > 80% capacidad
   - Riesgo de pérdida de mensajes

6. **Replication Lag**
   - `kafka.replica.lag` > 100ms
   - Problemas de consistencia

### Alertas Recomendadas:

```
CRÍTICO: Consumer lag > 5000 mensajes
CRÍTICO: Broker down por > 5 minutos
WARNING: Disk usage > 80%
WARNING: Error rate > 0.5%
INFO: Throughput < 50% del normal
```

## 🎯 Escenarios de Práctica

### 1. Incident Response Drill
```bash
# Simular caída de broker
./simulate-failures.sh broker-down

# Verificar impacto
./sre-commands.sh cluster-health
./sre-commands.sh consumer-lag

# Recuperar servicio
docker start kafka-broker-2
```

### 2. Capacity Planning
```bash
# Generar carga
python3 simulate-bank-traffic.py

# Monitorear métricas
./sre-commands.sh performance
./sre-commands.sh topic-partitions
```

### 3. Consumer Lag Investigation
```bash
# Crear lag artificial
./simulate-failures.sh consumer-lag

# Investigar
./sre-commands.sh consumer-lag
./sre-commands.sh consumer-groups
```

## 🚀 Scripts de Despliegue

### start-cluster.sh
```bash
#!/bin/bash

echo "🚀 Iniciando Cluster Kafka Bancario..."

# Verificar Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker no está ejecutándose"
    exit 1
fi

# Iniciar cluster
docker-compose -f docker-compose-cluster.yml up -d

# Esperar que esté listo
echo "⏳ Esperando cluster..."
sleep 60

# Crear topics bancarios
./create-bank-topics.sh

# Verificar estado
./sre-commands.sh cluster-health

echo "✅ Cluster bancario listo!"
echo "📊 Accesos:"
echo "   • Kafka UI: http://localhost:8080"
echo "   • Brokers: localhost:9092,9093,9094"
echo "   • Datadog: Dashboard configurado"
```

---

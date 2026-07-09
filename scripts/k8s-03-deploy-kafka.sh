#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

ENV="${1:-dev}"
case "$ENV" in
  dev)  CTX="kind-kafka-dev" ;;
  prod) CTX="kind-kafka-prod" ;;
  *) echo "Uso: $0 {dev|prod}"; exit 1 ;;
esac

echo "🎯 Contexto: $CTX"
echo "📦 Aplicando KafkaNodePool + Kafka + Topics..."
kubectl --context "$CTX" apply -f k8s/strimzi/01-kafka-nodepool.yaml
kubectl --context "$CTX" apply -f k8s/strimzi/02-kafka-cluster.yaml

echo "⏳ Esperando a que el cluster de Kafka esté listo (puede tardar 2-5 min)..."
kubectl --context "$CTX" wait kafka/kafka-lab \
  -n kafka-lab --for=condition=Ready --timeout=300s

echo "📦 Creando topics..."
kubectl --context "$CTX" apply -f k8s/strimzi/03-kafka-topics.yaml

echo "✅ Kafka listo en $CTX"
kubectl --context "$CTX" get kafka,kafkanodepool,kafkatopic,pods -n kafka-lab

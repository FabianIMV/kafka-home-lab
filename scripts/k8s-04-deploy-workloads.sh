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
echo "📦 Desplegando productor, consumidor y Kafka UI..."
kubectl --context "$CTX" apply -f k8s/workloads/

echo "⏳ Esperando a que los pods arranquen..."
kubectl --context "$CTX" -n kafka-lab rollout status deployment/lab-producer --timeout=120s
kubectl --context "$CTX" -n kafka-lab rollout status deployment/lab-consumer-orders --timeout=120s
kubectl --context "$CTX" -n kafka-lab rollout status deployment/kafka-ui --timeout=120s

echo "✅ Workloads corriendo en $CTX"
kubectl --context "$CTX" get pods -n kafka-lab
echo ""
echo "📊 Para ver Kafka UI:"
echo "   kubectl --context $CTX -n kafka-lab port-forward svc/kafka-ui 8080:8080"
echo "   luego abre http://localhost:8080"

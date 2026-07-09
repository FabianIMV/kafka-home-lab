#!/bin/bash
set -euo pipefail

ENV="${1:-dev}"
case "$ENV" in
  dev)  CTX="kind-kafka-dev" ;;
  prod) CTX="kind-kafka-prod" ;;
  *) echo "Uso: $0 {dev|prod}"; exit 1 ;;
esac

echo "🎯 Contexto: $CTX"
kubectl --context "$CTX" apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: kafka-lab
EOF

echo "📦 Instalando el operador Strimzi en el namespace 'kafka-lab'..."
kubectl --context "$CTX" apply -n kafka-lab -f 'https://strimzi.io/install/latest?namespace=kafka-lab'

echo "⏳ Esperando a que el operador esté listo..."
kubectl --context "$CTX" wait deployment/strimzi-cluster-operator \
  -n kafka-lab --for=condition=Available --timeout=180s

echo "✅ Operador Strimzi listo en $CTX"
kubectl --context "$CTX" get pods -n kafka-lab

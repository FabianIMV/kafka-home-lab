#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-dev}"

usage() {
  echo "Uso: $0 {dev|prod|both}"
  exit 1
}

check_tools() {
  for tool in kind kubectl docker; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "❌ Falta '$tool' en el PATH. Instálalo antes de continuar."
      exit 1
    fi
  done
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker no está corriendo."
    exit 1
  fi
}

create_cluster() {
  local name="$1"
  local config="$2"
  if kind get clusters 2>/dev/null | grep -qx "$name"; then
    echo "ℹ️  El cluster kind '$name' ya existe, no se recrea."
  else
    echo "🚀 Creando cluster kind '$name'..."
    kind create cluster --config "$config"
  fi
  echo "✅ Contexto disponible: kind-$name"
}

case "$TARGET" in
  dev)
    check_tools
    create_cluster kafka-dev k8s/kind/dev-cluster.yaml
    ;;
  prod)
    check_tools
    create_cluster kafka-prod k8s/kind/prod-cluster.yaml
    ;;
  both)
    check_tools
    create_cluster kafka-dev k8s/kind/dev-cluster.yaml
    create_cluster kafka-prod k8s/kind/prod-cluster.yaml
    ;;
  *)
    usage
    ;;
esac

echo ""
echo "📋 Contextos kubectl disponibles:"
kubectl config get-contexts

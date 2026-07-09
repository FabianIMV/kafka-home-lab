#!/bin/bash
set -euo pipefail

TARGET="${1:-dev}"

delete_cluster() {
  local name="$1"
  if kind get clusters 2>/dev/null | grep -qx "$name"; then
    echo "🗑️  Eliminando cluster kind '$name'..."
    kind delete cluster --name "$name"
  else
    echo "ℹ️  El cluster '$name' no existe, nada que borrar."
  fi
}

case "$TARGET" in
  dev)  delete_cluster kafka-dev ;;
  prod) delete_cluster kafka-prod ;;
  both)
    delete_cluster kafka-dev
    delete_cluster kafka-prod
    ;;
  *) echo "Uso: $0 {dev|prod|both}"; exit 1 ;;
esac

echo "✅ Limpieza completa."

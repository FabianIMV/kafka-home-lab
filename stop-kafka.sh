#!/bin/bash

echo "🛑 Deteniendo Kafka Home Lab..."

# Detener y eliminar contenedores
docker-compose down

echo "✅ Servicios detenidos correctamente"
echo ""
echo "💡 Para limpiar completamente (incluyendo volúmenes):"
echo "   docker-compose down -v"
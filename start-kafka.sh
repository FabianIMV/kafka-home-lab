#!/bin/bash

echo "🚀 Iniciando Kafka Home Lab..."

# Verificar que Docker esté ejecutándose
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker no está ejecutándose. Por favor inicia Docker primero."
    exit 1
fi

# Iniciar los servicios
echo "📦 Levantando contenedores..."
docker-compose up -d

# Esperar a que los servicios estén listos
echo "⏳ Esperando que los servicios estén listos..."
sleep 30

# Verificar estado de los servicios
echo "🔍 Verificando estado de los servicios..."
docker-compose ps

echo ""
echo "✅ Kafka Home Lab está listo!"
echo ""
echo "📊 Accesos disponibles:"
echo "   • Kafka UI: http://localhost:8080"
echo "   • Kafka Broker: localhost:9092"
echo "   • Zookeeper: localhost:2181"
echo ""
echo "🛠️  Comandos útiles:"
echo "   • ./stop-kafka.sh          - Detener servicios"
echo "   • ./test-kafka.sh          - Probar conexión"
echo "   • docker-compose logs -f   - Ver logs en tiempo real"
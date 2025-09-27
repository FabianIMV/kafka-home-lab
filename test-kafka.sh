#!/bin/bash

echo "🧪 Probando conectividad de Kafka..."

# Crear un topic de prueba
echo "📝 Creando topic de prueba..."
docker exec kafka-broker kafka-topics --create \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 1 \
  --replication-factor 1

# Listar topics
echo "📋 Topics disponibles:"
docker exec kafka-broker kafka-topics --list \
  --bootstrap-server localhost:9092

# Enviar un mensaje de prueba
echo "📤 Enviando mensaje de prueba..."
echo "Hola Kafka desde Home Lab!" | docker exec -i kafka-broker \
  kafka-console-producer --topic test-topic \
  --bootstrap-server localhost:9092

# Leer el mensaje
echo "📥 Leyendo mensajes del topic:"
timeout 5 docker exec kafka-broker \
  kafka-console-consumer --topic test-topic \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 1

echo "✅ Test completado. Si viste el mensaje 'Hola Kafka desde Home Lab!', todo funciona correctamente."
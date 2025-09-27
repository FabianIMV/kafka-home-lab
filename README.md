# Kafka Home Lab

Un entorno completo de Apache Kafka para desarrollo y pruebas locales usando Docker Compose.

## 🚀 Inicio Rápido

```bash
# Iniciar Kafka
./start-kafka.sh

# Probar conectividad
./test-kafka.sh

# Detener servicios
./stop-kafka.sh
```

## 📋 Servicios Incluidos

- **Apache Kafka** (puerto 9092) - Broker principal
- **Apache Zookeeper** (puerto 2181) - Coordinación de cluster
- **Kafka UI** (puerto 8080) - Interfaz web para administración

## 🌐 Accesos

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Kafka UI | http://localhost:8080 | Interfaz web para administrar Kafka |
| Kafka Broker | localhost:9092 | Conexión desde aplicaciones |
| Zookeeper | localhost:2181 | Servicio de coordinación |

## 🛠️ Comandos Útiles

### Gestión de Topics
```bash
# Crear topic
docker exec kafka-broker kafka-topics --create \
  --topic mi-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Listar topics
docker exec kafka-broker kafka-topics --list \
  --bootstrap-server localhost:9092

# Describir topic
docker exec kafka-broker kafka-topics --describe \
  --topic mi-topic \
  --bootstrap-server localhost:9092

# Eliminar topic
docker exec kafka-broker kafka-topics --delete \
  --topic mi-topic \
  --bootstrap-server localhost:9092
```

### Producir y Consumir Mensajes
```bash
# Productor (enviar mensajes)
docker exec -it kafka-broker kafka-console-producer \
  --topic mi-topic \
  --bootstrap-server localhost:9092

# Consumidor (leer mensajes desde el inicio)
docker exec -it kafka-broker kafka-console-consumer \
  --topic mi-topic \
  --bootstrap-server localhost:9092 \
  --from-beginning

# Consumidor con grupo
docker exec -it kafka-broker kafka-console-consumer \
  --topic mi-topic \
  --bootstrap-server localhost:9092 \
  --group mi-grupo
```

### Monitoreo
```bash
# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f kafka

# Estado de los contenedores
docker-compose ps

# Uso de recursos
docker stats
```

## 🔧 Configuración Avanzada

### Variables de Entorno Importantes

- `KAFKA_AUTO_CREATE_TOPICS_ENABLE=true` - Creación automática de topics
- `KAFKA_DELETE_TOPIC_ENABLE=true` - Permite eliminar topics
- `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1` - Para entorno single-broker

### Persistencia de Datos

Los datos se almacenan en volúmenes Docker:
- `kafka-data` - Datos de Kafka
- `zookeeper-data` - Datos de Zookeeper
- `zookeeper-logs` - Logs de Zookeeper

Para limpiar completamente los datos:
```bash
docker-compose down -v
```

## 📊 Usando Kafka UI

1. Abre http://localhost:8080
2. Explora topics, particiones y mensajes
3. Crea y gestiona topics desde la interfaz
4. Monitorea el rendimiento del cluster

## 🐛 Resolución de Problemas

### Servicios no inician
```bash
# Verificar Docker
docker info

# Ver logs de error
docker-compose logs

# Limpiar y reiniciar
docker-compose down -v
./start-kafka.sh
```

### Puerto ocupado
```bash
# Verificar puertos en uso
lsof -i :9092
lsof -i :8080
lsof -i :2181
```

### Conectividad
```bash
# Probar conexión básica
./test-kafka.sh

# Verificar red Docker
docker network ls
docker network inspect kafka-home-lab_default
```

## 📚 Recursos Adicionales

- [Documentación oficial de Kafka](https://kafka.apache.org/documentation/)
- [Kafka UI GitHub](https://github.com/provectus/kafka-ui)
- [Confluent Platform](https://docs.confluent.io/)

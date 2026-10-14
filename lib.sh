# Dùng chung: gọi CLI Kafka bên trong container
NAME=kafka-demo
BIN=/opt/kafka/bin
BS=localhost:9092
k() { ${ENGINE:-podman} exec -i "$NAME" "$@"; }

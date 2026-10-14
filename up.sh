#!/usr/bin/env bash
# Chạy 1 broker Kafka (KRaft, không cần Zookeeper) trên port 9092
. "$(dirname "$0")/lib.sh"
podman rm -f $NAME >/dev/null 2>&1
podman run -d --name $NAME -p 9092:9092 docker.io/apache/kafka:3.8.0 >/dev/null
echo -n "Đợi broker"
for i in $(seq 1 40); do
  k $BIN/kafka-broker-api-versions.sh --bootstrap-server $BS >/dev/null 2>&1 && { echo " OK"; exit 0; }
  echo -n .; sleep 1
done
echo " TIMEOUT"; exit 1

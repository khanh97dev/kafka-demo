#!/usr/bin/env bash
# Deploy nền tảng demo: Kafka (KRaft) + web mô phỏng.
#   ./deploy.sh up       chạy Kafka + web, tạo topic
#   ./deploy.sh down     dừng và xoá container
#   ./deploy.sh status   xem trạng thái
#   ./deploy.sh logs     log Kafka
#   ./deploy.sh demo     chạy demo CLI (produce/consume)
# Biến môi trường: WEB_PORT (8765), KAFKA_PORT (9092), KAFKA_IMAGE, ENGINE (podman|docker)
set -euo pipefail
cd "$(dirname "$0")"

ENGINE="${ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
command -v "$ENGINE" >/dev/null || { echo "Cần podman hoặc docker"; exit 1; }
WEB_PORT="${WEB_PORT:-8765}"
KAFKA_PORT="${KAFKA_PORT:-9092}"
KAFKA_IMAGE="${KAFKA_IMAGE:-docker.io/apache/kafka:3.8.0}"
WEB_IMAGE="${WEB_IMAGE:-docker.io/library/nginx:alpine}"
KAFKA=kafka-demo
WEB=kafka-demo-web
BIN=/opt/kafka/bin
BS=localhost:9092

kx() { "$ENGINE" exec -i "$KAFKA" "$@"; }

up() {
  "$ENGINE" rm -f "$KAFKA" "$WEB" >/dev/null 2>&1 || true
  echo "▶ Kafka ($KAFKA_IMAGE) :$KAFKA_PORT"
  "$ENGINE" run -d --name "$KAFKA" -p "$KAFKA_PORT:9092" "$KAFKA_IMAGE" >/dev/null
  echo -n "  đợi broker "
  for _ in $(seq 1 60); do
    kx $BIN/kafka-broker-api-versions.sh --bootstrap-server $BS >/dev/null 2>&1 && break
    echo -n .; sleep 1
  done
  kx $BIN/kafka-broker-api-versions.sh --bootstrap-server $BS >/dev/null 2>&1 || { echo " TIMEOUT"; exit 1; }
  echo " OK"

  echo "▶ Tạo topic"
  mk() { kx $BIN/kafka-topics.sh --bootstrap-server $BS --create --if-not-exists --topic "$1" --partitions "$2" --replication-factor 1 >/dev/null && echo "  $1 ($2 partition)"; }
  mk orders 3
  mk payments 2
  mk logs 6
  mk live.viewer-events 3

  echo "▶ Web mô phỏng :$WEB_PORT"
  "$ENGINE" run -d --name "$WEB" -p "$WEB_PORT:80" \
    -v "$PWD/index.html:/usr/share/nginx/html/index.html:ro" \
    -v "$PWD/sim.html:/usr/share/nginx/html/sim.html:ro" \
    -v "$PWD/live.html:/usr/share/nginx/html/live.html:ro" \
    "$WEB_IMAGE" >/dev/null
  echo
  echo "Xong:"
  echo "  Web   http://localhost:$WEB_PORT/"
  echo "  Kafka localhost:$KAFKA_PORT"
}

case "${1:-up}" in
  up) up ;;
  down) "$ENGINE" rm -f "$KAFKA" "$WEB" ;;
  status) "$ENGINE" ps --filter "name=kafka-demo" ;;
  logs) "$ENGINE" logs -f "$KAFKA" ;;
  demo) ENGINE="$ENGINE" ./demo.sh ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac

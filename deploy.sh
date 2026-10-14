#!/usr/bin/env bash
# Deploy bằng podman compose (hoặc docker compose, ENGINE=docker). Máy gửi / máy nhận scale độc lập.
#   ./deploy.sh up                      Kafka + topic + web
#   ./deploy.sh scale <P> <C> [N]       chạy P máy gửi, C máy nhận, mỗi máy gửi N record (mặc định 1_000_000)
#   ./deploy.sh stats                   CPU/RAM từng container
#   ./deploy.sh status | logs [svc] | clients-down | down
# Biến: KAFKA_PORT WEB_PORT PARTITIONS KAFKA_MEM KAFKA_CPUS CLIENT_CPUS CLIENT_MEM SIZE THROUGHPUT
set -euo pipefail
cd "$(dirname "$0")"
# Mặc định dùng podman nếu có (theo môi trường hiện tại), ép bằng ENGINE=docker
ENGINE="${ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
DC="$ENGINE compose"
export PARTITIONS="${PARTITIONS:-6}"

guard() { # chặn khi RAM/CPU không đủ cho cấu hình yêu cầu
  local p=$1 c=$2 need avail cpus_need cores
  need=$(( 3072 + (p + c) * 384 + 512 ))           # MB: Kafka + client + dư
  avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  cores=$(nproc)
  if [ "$need" -gt "$avail" ]; then
    echo "✗ Cần ~${need}MB RAM, chỉ còn ${avail}MB. Giảm số máy hoặc CLIENT_MEM." >&2; exit 1; fi
  # tổng CPU limit = 2 (kafka) + 0.5*(p+c) + 0.75; chừa tối thiểu 0.5 core
  cpus_need=$(awk -v p="$p" -v c="$c" 'BEGIN{print 2+0.5*(p+c)+0.75}')
  awk -v n="$cpus_need" -v k="$cores" 'BEGIN{exit !(n>k)}' && \
    echo "⚠ Tổng CPU limit ${cpus_need} > ${cores} core: các máy sẽ tranh nhau CPU (không crash, chỉ chậm). Nên P+C ≤ $(( (cores*2-5)/1 ))."
  return 0
}

case "${1:-up}" in
  up)
    $DC up -d --wait kafka topic-init web 2>&1 | tail -8 || true
    $DC up -d --wait kafka web
    echo; echo "Web   http://localhost:${WEB_PORT:-8765}/"
    echo "Kafka localhost:${KAFKA_PORT:-9092}  (trong mạng docker: kafka:19092)" ;;
  scale)
    P=${2:-1}; C=${3:-2}; N=${4:-1000000}
    guard "$P" "$C"
    export RECORDS=$N RECORDS_TOTAL=$(( N * P ))
    export GROUP="g-$(date +%s)"
    $DC rm -sf producer consumer >/dev/null 2>&1 || true
    $DC up -d --wait kafka >/dev/null
    # tạo lại topic bench đúng số partition (đồng bộ, trước khi client chạy)
    KT="$ENGINE exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092"
    $KT --delete --topic "${BENCH_TOPIC:-bench}" >/dev/null 2>&1 || true
    sleep 2
    $KT --create --topic "${BENCH_TOPIC:-bench}" --partitions "$PARTITIONS" --replication-factor 1 >/dev/null
    echo "▶ $C máy NHẬN (group $GROUP, cùng chia ${PARTITIONS} partition), $P máy GỬI × $N record"
    $DC up -d --no-deps --scale consumer="$C" consumer
    sleep 5
    $DC up -d --no-deps --scale producer="$P" --scale consumer="$C" producer consumer
    echo "Theo dõi:  ./deploy.sh stats   |   ./deploy.sh logs producer   |   ./deploy.sh logs consumer"
    echo "Dọn:       ./deploy.sh clients-down" ;;
  stats) $ENGINE stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' $($DC ps -q) ;;
  status) $DC ps -a ;;
  logs) shift; $DC logs --tail=200 "${@:-kafka}" ;;
  clients-down) $DC rm -sf producer consumer ;;
  down) $DC down -v ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac

#!/usr/bin/env bash
# Tải thử: A (producer) gửi N record, B và C (consumer cùng group) nhận song song.
#   ./bench.sh [N=3000000] [PARTITIONS=6] [SIZE=100]
. "$(dirname "$0")/lib.sh"
ENGINE="${ENGINE:-podman}"
N=${1:-3000000}; PARTS=${2:-6}; SIZE=${3:-100}
# --- Bảo vệ phần cứng: kiểm tra RAM/đĩa, giới hạn heap công cụ ---
MEM_AVAIL=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
DISK_FREE=$(df -Pm /tmp | awk 'NR==2{print $4}')
NEED_DISK=$(( N * (SIZE + 30) / 1024 / 1024 * 2 + 500 ))
[ "$MEM_AVAIL" -lt 2500 ] && { echo "RAM trống ${MEM_AVAIL}MB < 2500MB, dừng"; exit 1; }
[ "$DISK_FREE" -lt "$NEED_DISK" ] && { echo "Đĩa trống ${DISK_FREE}MB < cần ~${NEED_DISK}MB, dừng"; exit 1; }
k() { ${ENGINE} exec -i -e KAFKA_HEAP_OPTS="-Xms64m -Xmx256m" "$NAME" "$@"; }
T=bench-$(date +%s); G=g-$T
OUT=$(mktemp -d)
k $BIN/kafka-topics.sh --bootstrap-server $BS --create --topic $T --partitions $PARTS --replication-factor 1 >/dev/null
echo "topic=$T partitions=$PARTS records=$N size=${SIZE}B"

cons() { # $1=tên
  k $BIN/kafka-consumer-perf-test.sh --bootstrap-server $BS --topic $T --group $G \
    --messages $N --timeout 20000 --reporting-interval 5000 --show-detailed-stats > $OUT/$1.txt 2>&1 &
}
cons B; cons C
sleep 5   # để B, C vào group trước khi A gửi

echo "A gửi..."
k $BIN/kafka-producer-perf-test.sh --topic $T --num-records $N --record-size $SIZE \
  --throughput -1 --producer-props bootstrap.servers=$BS acks=1 linger.ms=10 batch.size=131072 \
  compression.type=lz4 > $OUT/A.txt 2>&1
echo "--- A (producer)"; tail -1 $OUT/A.txt
wait
for c in B C; do echo "--- $c (consumer)"; tail -3 $OUT/$c.txt; done
echo "--- phân bổ partition và lag"
k $BIN/kafka-consumer-groups.sh --bootstrap-server $BS --describe --group $G 2>/dev/null
k $BIN/kafka-get-offsets.sh --bootstrap-server $BS --topic $T

k $BIN/kafka-topics.sh --bootstrap-server $BS --delete --topic $T >/dev/null 2>&1 && echo "đã xoá topic $T"

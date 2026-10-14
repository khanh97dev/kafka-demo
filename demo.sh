#!/usr/bin/env bash
# Demo: key -> partition, consumer group chia partition
. "$(dirname "$0")/lib.sh"
P="$BIN/kafka-console-producer.sh --bootstrap-server $BS --property parse.key=true --property key.separator=:"

echo "=== 1. Produce 12 message vào 'orders' với key user1..user4 (cùng key => cùng partition) ==="
for i in $(seq 1 12); do echo "user$(( (i-1)%4+1 )):order-$i"; done | k $P --topic orders

echo; echo "=== 2. Offset mỗi partition của 'orders' ==="
k $BIN/kafka-get-offsets.sh --bootstrap-server $BS --topic orders

echo; echo "=== 3. Đọc từng partition (key -> partition cố định) ==="
for p in 0 1 2; do
  echo "--- partition $p"
  k $BIN/kafka-console-consumer.sh --bootstrap-server $BS --topic orders --partition $p --offset earliest \
    --property print.key=true --timeout-ms 4000 2>/dev/null
done

echo; echo "=== 4. Produce 'payments' + 'logs' ==="
for i in $(seq 1 6); do echo "pay$i:amount-$((i*10))"; done | k $P --topic payments
for i in $(seq 1 12); do echo "svc$((i%6)):log line $i"; done | k $P --topic logs

echo; echo "=== 5. 2 consumer cùng group g2 đọc 'orders' => chia 3 partition ==="
for c in A B; do
  k $BIN/kafka-console-consumer.sh --bootstrap-server $BS --topic orders --group g2 --from-beginning \
    --timeout-ms 25000 >/dev/null 2>&1 &
done
sleep 15
k $BIN/kafka-consumer-groups.sh --bootstrap-server $BS --describe --group g2 --members --verbose
wait
echo; k $BIN/kafka-consumer-groups.sh --bootstrap-server $BS --describe --group g2

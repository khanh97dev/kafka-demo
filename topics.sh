#!/usr/bin/env bash
# Tạo nhiều topic với số partition khác nhau
. "$(dirname "$0")/lib.sh"
mk() { k $BIN/kafka-topics.sh --bootstrap-server $BS --create --if-not-exists --topic "$1" --partitions "$2" --replication-factor 1; }
mk orders    3   # đơn hàng: 3 partition
mk payments  2   # thanh toán: 2 partition
mk logs      6   # log: nhiều partition cho thông lượng cao
echo; k $BIN/kafka-topics.sh --bootstrap-server $BS --describe

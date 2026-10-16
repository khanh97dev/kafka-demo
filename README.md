# kafka-demo

Demo Kafka chia nhiều topic / partition, kèm 2 trang mô phỏng producer – consumer.

## Web demo

Trải nghiệm giao diện mô phỏng trực tuyến: **[https://kafka.aiai.io.vn/](https://kafka.aiai.io.vn/)**

## Chạy local (Podman Compose hoặc `ENGINE=docker`)

```bash
./deploy.sh up                    # Kafka (KRaft) + web mô phỏng + topic
./deploy.sh scale 2 3 500000      # 2 máy GỬI x 500k record, 3 máy NHẬN (cùng group) song song
./deploy.sh stats                 # CPU/RAM từng container
./deploy.sh clients-down          # dọn máy gửi/nhận
./deploy.sh down
```

Web local: http://localhost:8765/ (đổi bằng `WEB_PORT`).

Giới hạn phần cứng (đổi bằng biến môi trường): Kafka `KAFKA_CPUS=2 KAFKA_MEM=3g` heap 1g; mỗi máy gửi/nhận
`CLIENT_CPUS=0.5 CLIENT_MEM=384m` heap 256m. `scale` từ chối chạy nếu RAM trống không đủ.
Số partition của topic tải thử: `PARTITIONS` (mặc định 6). Số máy nhận hữu ích tối đa = số partition.

## Nội dung

| File | Mô tả |
|---|---|
| `docker-compose.yml` | Kafka + topic-init + producer + consumer (scale được) + web |
| `deploy.sh` | up / scale / stats / status / logs / clients-down / down |
| `bench.sh` | Tải thử 1 container: A gửi, B/C nhận (CLI perf-test) |
| `topics.sh`, `demo.sh`, `up.sh`, `down.sh` | Script lẻ chạy CLI Kafka trong container |
| `sim.html` | Mô phỏng 2 panel Producer / Consumer, tooltip + bảng thuật ngữ |
| `live.html` | Ví dụ livestream user JOIN / LEAVE |

Topic: `orders` (3), `payments` (2), `logs` (6), `live.viewer-events` (3).

# kafka-demo

Demo Kafka chia nhiều topic / partition, kèm 2 trang mô phỏng producer – consumer.

## Chạy
```bash
./deploy.sh up      # Kafka (KRaft) + web mô phỏng, tạo topic
./deploy.sh demo    # demo CLI: key -> partition, consumer group chia partition
./deploy.sh down
```
Web: http://localhost:8765/ (đổi bằng `WEB_PORT`). Cần podman hoặc docker.

## Nội dung
| File | Mô tả |
|---|---|
| `deploy.sh` | Deploy nền tảng: up / down / status / logs / demo |
| `topics.sh`, `demo.sh`, `up.sh`, `down.sh` | Script lẻ chạy CLI Kafka trong container |
| `sim.html` | Mô phỏng 2 panel Producer / Consumer, tooltip + bảng thuật ngữ |
| `live.html` | Ví dụ livestream user JOIN / LEAVE |

Topic: `orders` (3), `payments` (2), `logs` (6), `live.viewer-events` (3).

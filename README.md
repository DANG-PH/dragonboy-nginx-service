<p align="center">
  <img src="https://i.pinimg.com/originals/fd/91/b1/fd91b1715061efc79dbb6678aea0f9b9.gif" width="220" alt="Ngọc Rồng Online">
</p>

<h1 align="center">NRO Nginx Service</h1>

<p align="center">
  <em>Nginx Load Balancer · Reverse Proxy · SSL Termination · Full Docker Stack · Automated Backups</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Nginx-reverse_proxy-009639?style=flat&logo=nginx&logoColor=white" alt="Nginx"/>
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Bash-Scripts-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/Let's_Encrypt-SSL-003A70?style=flat&logo=letsencrypt&logoColor=white" alt="Let's Encrypt"/>
  <img src="https://img.shields.io/badge/Prometheus-metrics-E6522C?style=flat&logo=prometheus&logoColor=white" alt="Prometheus"/>
  <img src="https://img.shields.io/badge/Grafana-dashboards-F46800?style=flat&logo=grafana&logoColor=white" alt="Grafana"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat&logo=mysql&logoColor=white" alt="MySQL"/>
  <img src="https://img.shields.io/badge/PostgreSQL-15-4169E1?style=flat&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/MongoDB-latest-47A248?style=flat&logo=mongodb&logoColor=white" alt="MongoDB"/>
  <img src="https://img.shields.io/badge/Redis-cache-DC382D?style=flat&logo=redis&logoColor=white" alt="Redis"/>
  <img src="https://img.shields.io/badge/RabbitMQ-broker-FF6600?style=flat&logo=rabbitmq&logoColor=white" alt="RabbitMQ"/>
  <img src="https://img.shields.io/badge/NATS-messaging-27AAE1?style=flat&logo=natsdotio&logoColor=white" alt="NATS"/>
  <img src="https://img.shields.io/badge/Jaeger-tracing-66CFE3?style=flat&logo=jaeger&logoColor=white" alt="Jaeger"/>
</p>

<p align="center">
  <a href="https://github.com/DANG-PH/NgocRongOnline">
    <img src="https://img.shields.io/badge/Game_chính-NgocRongOnline-181717?style=for-the-badge&logo=github&logoColor=white" alt="Game repo"/>
  </a>
  &nbsp;
  <a href="https://ngocrongdark.com">
    <img src="https://img.shields.io/badge/▶_CHƠI_NGAY-ngocrongdark.com-FF6B35?style=for-the-badge&logoColor=white" alt="Play Now"/>
  </a>
</p>

<p align="center">
  Tầng <strong>hạ tầng (infrastructure)</strong> cho dự án <strong>Ngọc Rồng Online</strong> – tựa game MMORPG<br>
  lấy cảm hứng từ bộ truyện <strong>Dragon Ball (7 Viên Ngọc Rồng)</strong> của tác giả Akira Toriyama.<br>
  Đảm nhận load balancing, reverse proxy, SSL, toàn bộ tầng database và hệ thống backup tự động.
</p>

---

## Repo này là gì?

Đây là **lớp hạ tầng** chạy trên một VPS chuyên biệt, đứng trước các microservice game (NestJS + Go). Nó gánh toàn bộ phần "không phải logic game" để các service ứng dụng chỉ việc tập trung xử lý gameplay:

- **Nginx** làm reverse proxy + load balancer cho các microservice, terminate SSL cho mọi domain, và bảo vệ các trang quản trị bằng basic-auth.
- **Docker Compose** dựng toàn bộ tầng dữ liệu (MySQL, PostgreSQL, MongoDB, Redis), message broker (RabbitMQ, NATS), các UI quản trị, và bộ giám sát (Prometheus + Grafana + Jaeger).
- **Hệ thống backup** tự động dump cả 4 database mỗi đêm và lưu ra 3 nơi (local, GitHub, Google Drive).
- **CI/CD** tự kích hoạt deploy khi push lên `master` thông qua một repo devops trung tâm.

> Các microservice game nằm ở repo riêng và chạy trên các VPS ứng dụng (`103.116.52.222`, `103.116.52.219`). Repo này là tầng hạ tầng + dữ liệu phía sau chúng.

---

## Kiến trúc tổng thể

```
                           Người chơi / Client
                                   │
                                   │  HTTPS (443)
                                   ▼
                    ┌──────────────────────────────┐
                    │      Nginx (VPS hạ tầng)      │
                    │  SSL termination · LB · auth  │
                    └───────────────┬──────────────┘
                  ┌─────────────────┼─────────────────┐
                  ▼                 ▼                 ▼
        api.ngocrongdark    ws / ws-go (game)   data/redis/postgres
         (NestJS gateway)   (NestJS + Go)        (UI quản trị)
                  │                 │
        ┌─────────┴─────────┐       │   least_conn load balance
        ▼                   ▼       ▼
   103.116.52.222     103.116.52.219    (2 VPS ứng dụng)
        │                   │
        └─────────┬─────────┘
                  ▼
   ┌──────────────────────────────────────────────┐
   │   Tầng dữ liệu (Docker, trên VPS hạ tầng)     │
   │   MySQL · PostgreSQL · MongoDB · Redis        │
   │   RabbitMQ · NATS · Prometheus · Grafana      │
   └──────────────────┬───────────────────────────┘
                      ▼
        backup.sh (cron 4:00) → Local + GitHub + Google Drive
```

Hai VPS ứng dụng được cân bằng tải bằng thuật toán `least_conn` (ưu tiên server đang có ít kết nối nhất), với `max_fails=3` và `fail_timeout=30s` để tự loại server lỗi ra khỏi vòng quay.

---

## Thành phần dịch vụ

Toàn bộ định nghĩa trong [`docker-compose.yml`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/docker-compose.yml). Mọi cổng đều bind vào `127.0.0.1` (chỉ lộ ra ngoài qua Nginx), trừ NATS.

### Database

| Service | Image | Cổng nội bộ | Vai trò |
|---|---|---|---|
| **mysql-nro** | `mysql:8.0` | 3306 | DB chính cho game (nhiều schema, xem bên dưới) |
| **postgres** | `postgres:15` | 5432 | DB phụ trợ |
| **mongo** | `mongo` | 27017 | Lưu dữ liệu dạng document |
| **redis** | `redis` | 6379 | Cache / session / pub-sub |

### Message broker

| Service | Image | Cổng | Vai trò |
|---|---|---|---|
| **rabbitmq** | `rabbitmq:management` | 5672 / 15672 | Hàng đợi tin nhắn + UI quản lý |
| **nats** | `nats:latest` | 4222 | Messaging nhẹ, độ trễ thấp |

### UI quản trị (sau Nginx + basic-auth)

| Service | Truy cập qua | Quản lý |
|---|---|---|
| **phpmyadmin** | `data.ngocrongdark.com` | MySQL |
| **pgadmin** | `postgres.ngocrongdark.com` | PostgreSQL |
| **redisinsight** | `redis.ngocrongdark.com` | Redis |
| **mongo-express** | (nội bộ) | MongoDB |

### Giám sát (observability)

| Service | Image | Vai trò |
|---|---|---|
| **prometheus** | `prom/prometheus` | Thu thập metrics (retention 30 ngày) |
| **grafana** | `grafana/grafana` | Dashboard, qua `grafana.ngocrongdark.com` |
| **jaeger** | `jaegertracing/jaeger` | Distributed tracing |

Prometheus scrape metrics từ cả 4 nhóm service trên 2 VPS ứng dụng (NestJS gateway / pay / game + Go game), cấu hình trong [`prometheus.yml`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/prometheus.yml).

---

## Nginx — điểm nhấn cấu hình

File [`nginx.conf`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/nginx.conf) gánh nhiều việc cùng lúc:

**Reverse proxy theo domain.** Mỗi domain (api, pay, data, redis, postgres, ws, ws-go, grafana, download) là một `server` block riêng, tất cả tự chuyển hướng HTTP→HTTPS bằng `return 301`.

**Load balancing.** Các upstream (`api_gateway`, `pay_service`, `game_service`, `game_service_go`) dùng `least_conn` phân phối qua 2 VPS ứng dụng, có `keepalive` để tái dùng kết nối — giảm overhead bắt tay TCP khi traffic cao.

**WebSocket.** Các domain `ws` và `ws-go` xử lý nâng cấp kết nối qua `map $http_upgrade`, đặt `proxy_read_timeout 3600s` và `proxy_buffering off` để giữ kết nối real-time lâu dài cho gameplay.

**Bảo mật.** HSTS preload + `X-Frame-Options` trên mọi HTTPS block; basic-auth khoá các UI quản trị và endpoint nhạy cảm (`/` gốc, `/api-docs` Swagger của gateway).

**TCP stream (Layer 4).** Khối `stream {}` mở các cổng đệm (`33306`→MySQL, `36379`→Redis, `35432`→Postgres, `35674`→RabbitMQ, `37017`→Mongo) để VPS ứng dụng kết nối trực tiếp tới database. Các cổng này được **UFW whitelist chỉ cho IP của 2 VPS ứng dụng** (cấu hình trong `bootstrap.sh`).

> Trang `download.ngocrongdark.com` chỉ redirect 302 sang [GitHub Releases](https://github.com/DANG-PH/NgocRongOnline/releases) để client tải bản game mới nhất.

---

## Cài đặt VPS mới (one-command)

Toàn bộ quá trình được tự động hoá trong [`backup/scripts/bootstrap.sh`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/backup/scripts/bootstrap.sh).

**Bước 1 — Clone repo:**

```bash
git clone https://github.com/DANG-PH/dragonboy-nginx-service.git
cd dragonboy-nginx-service
```

**Bước 2 — Chạy bootstrap với quyền root:**

```bash
sudo ./backup/scripts/bootstrap.sh
```

Script tự làm **14 bước** (~15–20 phút):

| # | Bước | # | Bước |
|---|---|---|---|
| 1 | Cài tool cơ bản (curl, git, htpasswd...) | 8 | Certbot + SSL + fix permission |
| 2 | Timezone `Asia/Ho_Chi_Minh` | 9 | Auto-renewal SSL |
| 3 | Swap 2GB + `vm.swappiness=10` | 10 | `docker compose up -d` |
| 4 | Cài Docker | 11 | Verify nginx config + DB containers |
| 5 | UFW firewall + whitelist DB ports | 12 | Cài rclone + cấu hình Google Drive |
| 6 | Tạo `.env` (user điền) | 13 | Logrotate |
| 7 | Tạo `htpasswd` cho nginx | 14 | Đăng ký cron backup |

> **Trước khi chạy:** đảm bảo tất cả domain đã trỏ DNS về IP VPS hạ tầng, và có sẵn máy local có trình duyệt để hoàn tất OAuth của rclone (Google Drive).

---

## Cấu hình `.env`

Copy từ mẫu [`.env.example`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/.env.example) rồi điền (`bootstrap.sh` tự làm bước này, nhưng có thể chỉnh tay):

```bash
cp .env.example .env
nano .env       # chmod 600 tự động
```

Các nhóm biến chính:

| Nhóm | Biến tiêu biểu | Ghi chú |
|---|---|---|
| **Database** | `MYSQL_PASS`, `MONGO_USER/PASS`, `PG_USER/PASS/DB` | Phải khớp `docker-compose.yml` |
| **Container names** | `MYSQL_CONTAINER`, `MONGO_CONTAINER`... | Mặc định: `mysql-nro`, `mongo`, `postgres`, `redis` |
| **Nginx auth** | `HTPASSWD_USER`, `HTPASSWD_PASS` | Basic-auth cho UI quản trị |
| **UI tools** | `REDIS_INSIGHT_*`, `RABBITMQ_*`, `ME_BASICAUTH_*`, `PGADMIN_*` | Tài khoản các dashboard |
| **Monitoring** | `GRAFANA_USER`, `GRAFANA_PASS` | Đăng nhập Grafana |
| **Backup** | `RCLONE_REMOTE`, `LOCAL_RETENTION_DAYS`, `DRIVE_RETENTION_DAYS`, `CRON_HOUR/MINUTE`, `GITHUB_BACKUP_DIR` | Cấu hình lịch & lưu trữ |

> Mật khẩu có ký tự đặc biệt (`@`, `$`, `!`) phải bọc nháy đơn: `MYSQL_PASS='Phamhaidang112@'`

### Schema khởi tạo MySQL

File [`configAdmin.sql`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/configAdmin.sql) được mount vào `docker-entrypoint-initdb.d`, tự chạy khi container MySQL khởi tạo lần đầu. Nó tạo sẵn các database theo từng domain nghiệp vụ (`auth_db`, `item_db`, `user_db`, `social_db`, `pay_db`, `game_data_db`...) và seed dữ liệu nền (danh sách NPC, map) bằng `INSERT IGNORE` để an toàn khi container restart.

---

## Hệ thống backup & restore

4 script trong [`backup/scripts/`](https://github.com/DANG-PH/dragonboy-nginx-service/tree/master/backup/scripts) điều khiển toàn bộ vòng đời backup:

| Script | Chức năng |
|---|---|
| [`bootstrap.sh`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/backup/scripts/bootstrap.sh) | Setup VPS mới từ A–Z (14 bước) |
| [`setup.sh`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/backup/scripts/setup.sh) | Cài rclone + đăng ký cron (không setup lại toàn VPS) |
| [`backup.sh`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/backup/scripts/backup.sh) | Dump 4 DB → local → Google Drive → GitHub → dọn file cũ |
| [`restore.sh`](https://github.com/DANG-PH/dragonboy-nginx-service/blob/master/backup/scripts/restore.sh) | Khôi phục DB từ local / GitHub / Drive |

**Chiến lược 3 lớp (3-2-1):** mỗi đêm `backup.sh` dump cả 4 database rồi lưu ra ba nơi độc lập — bản local (restore nhanh nhất), GitHub (versioned theo commit), và Google Drive (off-site phòng VPS hỏng). Bản dữ liệu được đẩy lên repo private [**dragonboy-db-backups**](https://github.com/DANG-PH/dragonboy-db-backups).

**Không downtime:** MySQL dump với `--single-transaction`, Redis dùng `BGSAVE` (lưu nền) nên container vẫn phục vụ bình thường trong lúc backup.

### Backup thủ công

```bash
./backup/scripts/backup.sh
crontab -l                      # xem cron đã đăng ký
tail -f backup/backup.log       # theo dõi log
```

### Restore

> ⚠️ Restore sẽ **ghi đè** dữ liệu hiện tại. Script hỏi xác nhận (`yes`) trước khi chạy.

```bash
# Cú pháp
./backup/scripts/restore.sh <mysql|mongo|pg|redis> <tên_file> [--from-github|--from-drive]

# Ví dụ
./backup/scripts/restore.sh mysql mysql_2026-05-22_0400.sql.gz
./backup/scripts/restore.sh pg    pg_2026-05-22_0400.sql.gz --from-github
./backup/scripts/restore.sh mongo mongo_2026-05-22_0400.archive.gz --from-drive
```

| DB | Cơ chế restore |
|---|---|
| **MySQL** | `gunzip` → pipe vào `mysql` trong container |
| **PostgreSQL** | `gunzip` → pipe vào `psql` |
| **MongoDB** | `mongorestore --archive --gzip --drop` |
| **Redis** | Stop container → thay `dump.rdb` → start lại |

---

## CI/CD

Workflow trong [`.github/workflows`](https://github.com/DANG-PH/dragonboy-nginx-service/tree/master/.github/workflows) chạy khi push lên `master`. Thay vì tự deploy, nó gửi một **`repository_dispatch`** (sự kiện `deploy`) tới repo devops trung tâm `dragonboy-devops-service` qua GitHub API, kèm payload (tên service, thư mục, commit, người push...). Repo devops nhận tín hiệu rồi thực hiện deploy thực tế.

Cách tách này giúp logic deploy tập trung một chỗ, các repo service chỉ cần "báo có thay đổi" — gọn và dễ bảo trì khi số lượng service tăng.

---

## Lịch & vòng đời

| Tác vụ | Thời điểm | Ghi chú |
|---|---|---|
| Backup DB | `CRON_HOUR:CRON_MINUTE` (mặc định **4:00**) | Hằng ngày |
| Auto-renew SSL | 3:00 | Certbot + tự reload nginx |
| Dọn local + GitHub | sau mỗi backup | Xoá file cũ hơn `LOCAL_RETENTION_DAYS` (7) |
| Dọn Google Drive | sau mỗi backup | Theo `DRIVE_RETENTION_DAYS` (30) |
| Xoay log | hằng tuần | Logrotate, giữ 4 tuần |
| Prometheus retention | 30 ngày | TSDB |

---

## Cấu trúc repo

```
dragonboy-nginx-service/
├── .github/workflows/      # CI: trigger deploy sang devops-service
├── backup/
│   ├── scripts/
│   │   ├── bootstrap.sh     # setup VPS A-Z (14 bước)
│   │   ├── setup.sh         # cài rclone + cron
│   │   ├── backup.sh        # dump 4 DB → 3 nơi
│   │   └── restore.sh       # khôi phục DB
│   └── backup.log
├── docker-compose.yml      # toàn bộ stack
├── nginx.conf              # reverse proxy + LB + stream
├── nginx.md                # ghi chú cấu hình nginx
├── prometheus.yml          # scrape config
├── configAdmin.sql         # init schema MySQL
└── .env.example            # mẫu biến môi trường
```

---

## Hướng phát triển

Một vài ý tưởng có thể mở rộng trong tương lai:

- **Tách SSL cert riêng cho từng domain** thay vì dùng chung cert của `api.ngocrongdark.com` (hiện đã hoạt động nhờ cert đa domain, nhưng tách ra sẽ linh hoạt hơn khi thêm/bớt domain).
- **Health-check chủ động** cho các upstream để Nginx phát hiện service chết sớm hơn cơ chế `max_fails` thụ động.
- **Alerting** cho Prometheus (Alertmanager) để được báo khi service/DB gặp vấn đề, thay vì chỉ xem dashboard.
- **Object storage** (Backblaze B2 / Cloudflare R2) cho các bản dump lớn, giảm áp lực lên giới hạn 100MB/file của GitHub khi database phình to.

---

<p align="center">
  <sub>Tầng hạ tầng cho dự án <strong>Ngọc Rồng Online</strong> · <a href="https://ngocrongdark.com">ngocrongdark.com</a></sub>
</p>
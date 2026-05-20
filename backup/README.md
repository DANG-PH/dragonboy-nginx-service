# Backup & Restore System

Tự động backup database (MySQL, MongoDB, PostgreSQL, Redis) lên Google Drive hàng ngày.

## Cấu trúc

```
backup/
├── scripts/
│   ├── backup.sh      # script backup (cron tự gọi)
│   ├── restore.sh     # script restore (chạy tay khi cần)
│   └── setup.sh       # script setup lần đầu
├── data/              # nơi lưu file backup local (gitignore)
└── README.md
```

## Setup lần đầu (VPS mới)

### Bước 1: Clone repo và bật stack

```bash
git clone <repo-url>
cd <repo>
cp .env.example .env
nano .env                    # điền password và config
docker compose up -d         # bật stack
```

### Bước 2: Cấu hình rclone (Google Drive)

Cài rclone tạm để cấu hình:

```bash
curl https://rclone.org/install.sh | sudo bash
rclone config
```

Trả lời các prompt:

| Prompt | Trả lời |
|---|---|
| `e/n/d/r/c/s/q>` | `n` (new remote) |
| `name>` | `gdrive` (trùng với `RCLONE_REMOTE` trong `.env`) |
| `Storage>` | `drive` |
| `client_id>` | (Enter, để trống) |
| `client_secret>` | (Enter, để trống) |
| `scope>` | `1` (full access) |
| `service_account_file>` | (Enter, để trống) |
| `Edit advanced config?` | `n` |
| `Use web browser to automatically authenticate?` | `n` (vì VPS không có browser) |
| `config_token>` | Xem hướng dẫn dưới ↓ |
| `Configure this as a Shared Drive?` | `n` |
| `Keep this remote?` | `y` |

**Lấy `config_token`**:

1. rclone sẽ in ra 1 lệnh `rclone authorize "drive" "..."`. Copy nguyên lệnh đó.
2. Trên máy local (Windows/Mac có browser), cài rclone từ https://rclone.org/downloads/
3. Chạy lệnh `rclone authorize` đã copy → browser tự mở → đăng nhập Google → Allow
4. Terminal local sẽ in ra 1 chuỗi JSON dài
5. Copy chuỗi đó, paste vào prompt `config_token>` trên VPS

### Bước 3: Chạy setup.sh

```bash
./backup/scripts/setup.sh
```

Script này sẽ:
- Verify containers đang chạy
- Test kết nối Drive
- Cấp quyền execute cho scripts
- Đăng ký cron job

### Bước 4: Test backup tay

```bash
./backup/scripts/backup.sh
```

Verify file đã upload:

```bash
ls -lh backup/data/
rclone ls gdrive:db-backups
```

## Restore khi cần

```bash
# Liệt kê backup local
ls backup/data/

# Nếu local không có, tải từ Drive về
rclone copy gdrive:db-backups/mysql_2026-05-20_0400.sql.gz backup/data/

# Restore
./backup/scripts/restore.sh mysql mysql_2026-05-20_0400.sql.gz
```

Tham số: `mysql` | `mongo` | `pg` | `redis`.

## Theo dõi

```bash
# Log backup
tail -f backup/backup.log

# Kiểm tra cron
crontab -l

# Kiểm tra dung lượng
du -sh backup/data/
rclone size gdrive:db-backups
```

## Retention policy

Mặc định trong `.env`:
- Local: giữ 7 ngày
- Google Drive: giữ 30 ngày

Đổi giá trị trong `.env` và chạy lại `setup.sh` (hoặc sửa cron trực tiếp).

## Troubleshooting

**Cron không chạy**: Check `journalctl -u cron --since "10 min ago"` và đảm bảo dòng `PATH=...` có trong `crontab -l`.

**rclone báo token expired**: Chạy `rclone config reconnect gdrive:`.

**Postgres restore báo `database "admin" does not exist`**: Đã fix trong script (thêm `-d postgres`). Nếu vẫn lỗi, đảm bảo dùng phiên bản script mới nhất.

Xem chi tiết hơn trong `BACKUP_RESTORE_GUIDE.md` ở root repo.
#!/bin/bash
# Backup script: dump 4 DB → local → upload Google Drive
# Chạy hàng ngày qua cron

set -euo pipefail

# ============ ĐỊNH VỊ ============
# Path tuyệt đối tới script này (chạy được dù gọi từ đâu)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$REPO_ROOT/backup/data"

# ============ LOAD CONFIG ============
if [ ! -f "$REPO_ROOT/.env" ]; then
  echo "ERROR: Không tìm thấy file $REPO_ROOT/.env"
  echo "Hãy copy .env.example thành .env và điền thông tin."
  exit 1
fi

set -a   # auto-export biến
source "$REPO_ROOT/.env"
set +a

DATE=$(date +%F_%H%M)
LOG_PREFIX="[$(date '+%F %T')]"

# ============ KHỞI ĐỘNG ============
mkdir -p "$BACKUP_DIR"
echo "$LOG_PREFIX === Bắt đầu backup ==="

# ============ MYSQL ============
echo "$LOG_PREFIX [MySQL] Đang dump..."
docker exec "$MYSQL_CONTAINER" sh -c "exec mysqldump -uroot -p\"$MYSQL_PASS\" --all-databases --single-transaction --routines --triggers" \
  | gzip > "$BACKUP_DIR/mysql_$DATE.sql.gz"
echo "$LOG_PREFIX [MySQL] Done. Size: $(du -h "$BACKUP_DIR/mysql_$DATE.sql.gz" | cut -f1)"

# ============ MONGODB ============
echo "$LOG_PREFIX [MongoDB] Đang dump..."
docker exec "$MONGO_CONTAINER" sh -c "exec mongodump -u $MONGO_USER -p $MONGO_PASS --authenticationDatabase admin --archive --gzip" \
  > "$BACKUP_DIR/mongo_$DATE.archive.gz"
echo "$LOG_PREFIX [MongoDB] Done. Size: $(du -h "$BACKUP_DIR/mongo_$DATE.archive.gz" | cut -f1)"

# ============ POSTGRESQL ============
echo "$LOG_PREFIX [Postgres] Đang dump..."
docker exec "$POSTGRES_CONTAINER" sh -c "exec pg_dumpall -U $PG_USER" \
  | gzip > "$BACKUP_DIR/pg_$DATE.sql.gz"
echo "$LOG_PREFIX [Postgres] Done. Size: $(du -h "$BACKUP_DIR/pg_$DATE.sql.gz" | cut -f1)"

# ============ REDIS ============
echo "$LOG_PREFIX [Redis] Đang BGSAVE..."
LAST_SAVE_BEFORE=$(docker exec "$REDIS_CONTAINER" redis-cli LASTSAVE)
docker exec "$REDIS_CONTAINER" redis-cli BGSAVE > /dev/null
for i in {1..30}; do
  sleep 1
  LAST_SAVE_NOW=$(docker exec "$REDIS_CONTAINER" redis-cli LASTSAVE)
  if [ "$LAST_SAVE_NOW" != "$LAST_SAVE_BEFORE" ]; then
    break
  fi
done
docker cp "$REDIS_CONTAINER":/data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"
gzip "$BACKUP_DIR/redis_$DATE.rdb"
echo "$LOG_PREFIX [Redis] Done. Size: $(du -h "$BACKUP_DIR/redis_$DATE.rdb.gz" | cut -f1)"

# ============ UPLOAD GOOGLE DRIVE ============
echo "$LOG_PREFIX [Drive] Đang upload..."
rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE" --include "*_$DATE.*"
echo "$LOG_PREFIX [Drive] Done."

# ============ PUSH GITHUB ============
echo "$LOG_PREFIX [GitHub] Đang copy & push..."
cp "$BACKUP_DIR"/*_$DATE.* "$GITHUB_BACKUP_DIR/"
cd "$GITHUB_BACKUP_DIR/.."
git add data/
git commit -m "backup: $DATE"
git push origin main
echo "$LOG_PREFIX [GitHub] Done."

# ============ DỌN FILE CŨ ============
echo "$LOG_PREFIX [Cleanup] Xoá file cũ..."
find "$BACKUP_DIR" -type f -mtime +$LOCAL_RETENTION_DAYS -delete
rclone delete "$RCLONE_REMOTE" --min-age ${DRIVE_RETENTION_DAYS}d
find "$GITHUB_BACKUP_DIR" -type f \( -name "*.gz" -o -name "*.rdb" \) -mtime +$LOCAL_RETENTION_DAYS -delete
cd "$GITHUB_BACKUP_DIR/.."
git add data/
git commit -m "cleanup: remove backups older than $LOCAL_RETENTION_DAYS days" --allow-empty
git push origin main
echo "$LOG_PREFIX [Cleanup] Done."

echo "$LOG_PREFIX === Hoàn tất ==="
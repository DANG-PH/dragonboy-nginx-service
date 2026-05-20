#!/bin/bash
# Restore script
# Usage: ./restore.sh <mysql|mongo|pg|redis> <backup_file>

set -euo pipefail

# ============ ĐỊNH VỊ ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$REPO_ROOT/backup/data"

# ============ LOAD CONFIG ============
if [ ! -f "$REPO_ROOT/.env" ]; then
  echo "ERROR: Không tìm thấy file $REPO_ROOT/.env"
  exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

DB="${1:-}"
FILE="${2:-}"

if [ -z "$DB" ] || [ -z "$FILE" ]; then
  echo "Usage: $0 <mysql|mongo|pg|redis> <backup_file>"
  echo ""
  echo "Backup có sẵn local trong $BACKUP_DIR:"
  ls -1 "$BACKUP_DIR" 2>/dev/null || echo "  (trống)"
  echo ""
  echo "Để tải từ Google Drive về local trước:"
  echo "  rclone copy $RCLONE_REMOTE/<tên_file> $BACKUP_DIR/"
  exit 1
fi

# Nếu file không có path → tìm trong BACKUP_DIR
if [ ! -f "$FILE" ]; then
  if [ -f "$BACKUP_DIR/$FILE" ]; then
    FILE="$BACKUP_DIR/$FILE"
  else
    echo "Lỗi: không tìm thấy file $FILE"
    exit 1
  fi
fi

echo "Sắp restore $DB từ: $FILE"
echo "⚠️  CẢNH BÁO: Dữ liệu hiện tại sẽ bị ghi đè."
read -p "Tiếp tục? (gõ 'yes' để xác nhận): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Đã huỷ."
  exit 0
fi

case "$DB" in
  mysql)
    gunzip < "$FILE" | docker exec -i "$MYSQL_CONTAINER" sh -c "exec mysql -uroot -p\"$MYSQL_PASS\""
    ;;
  mongo)
    docker exec -i "$MONGO_CONTAINER" sh -c "exec mongorestore -u $MONGO_USER -p $MONGO_PASS --authenticationDatabase admin --archive --gzip --drop" < "$FILE"
    ;;
  pg)
    gunzip < "$FILE" | docker exec -i "$POSTGRES_CONTAINER" sh -c "exec psql -U $PG_USER -d postgres"
    ;;
  redis)
    TMP=$(mktemp)
    gunzip < "$FILE" > "$TMP"
    docker stop "$REDIS_CONTAINER"
    docker cp "$TMP" "$REDIS_CONTAINER":/data/dump.rdb
    docker start "$REDIS_CONTAINER"
    rm "$TMP"
    ;;
  *)
    echo "DB không hợp lệ: $DB (phải là mysql|mongo|pg|redis)"
    exit 1
    ;;
esac

echo "✓ Restore xong."
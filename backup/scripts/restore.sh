#!/bin/bash
# Restore script
# Usage: ./restore.sh <mysql|mongo|pg|redis> <backup_file> [--from-github|--from-drive]

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
SOURCE="${3:-}"

if [ -z "$DB" ] || [ -z "$FILE" ]; then
  echo "Usage: $0 <mysql|mongo|pg|redis> <backup_file> [--from-github|--from-drive]"
  echo ""
  echo "Backup có sẵn local trong $BACKUP_DIR:"
  ls -1 "$BACKUP_DIR" 2>/dev/null || echo "  (trống)"
  echo ""
  echo "Ví dụ:"
  echo "  $0 mysql mysql_2026-05-22_0400.sql.gz"
  echo "  $0 mysql mysql_2026-05-22_0400.sql.gz --from-github"
  echo "  $0 mysql mysql_2026-05-22_0400.sql.gz --from-drive"
  exit 1
fi

# ============ TẢI FILE NẾU CẦN ============
case "$SOURCE" in
  --from-github)
    echo "Đang pull từ GitHub..."
    cd "$GITHUB_BACKUP_DIR/.."
    git pull origin main
    echo "✓ Pull xong"
    if [ -f "$GITHUB_BACKUP_DIR/$FILE" ]; then
      cp "$GITHUB_BACKUP_DIR/$FILE" "$BACKUP_DIR/"
      echo "✓ Copy từ GitHub về local: $FILE"
    else
      echo "Lỗi: không tìm thấy $FILE trong GitHub repo"
      echo "Các file có sẵn:"
      ls -1 "$GITHUB_BACKUP_DIR" 2>/dev/null || echo "  (trống)"
      exit 1
    fi
    ;;
  --from-drive)
    echo "Đang tải từ Google Drive..."
    rclone copy "$RCLONE_REMOTE/$FILE" "$BACKUP_DIR/"
    if [ -f "$BACKUP_DIR/$FILE" ]; then
      echo "✓ Tải từ Drive về local: $FILE"
    else
      echo "Lỗi: không tìm thấy $FILE trên Drive"
      echo "Các file có sẵn:"
      rclone ls "$RCLONE_REMOTE" 2>/dev/null || echo "  (trống)"
      exit 1
    fi
    ;;
  "")
    # Không có option → tìm local
    ;;
  *)
    echo "Option không hợp lệ: $SOURCE (phải là --from-github hoặc --from-drive)"
    exit 1
    ;;
esac

# ============ TÌM FILE LOCAL ============
if [ ! -f "$FILE" ]; then
  if [ -f "$BACKUP_DIR/$FILE" ]; then
    FILE="$BACKUP_DIR/$FILE"
  else
    echo "Lỗi: không tìm thấy file $FILE"
    echo ""
    echo "Thử tải từ nguồn khác:"
    echo "  $0 $DB $FILE --from-github"
    echo "  $0 $DB $FILE --from-drive"
    exit 1
  fi
fi

# ============ CONFIRM ============
echo ""
echo "Sắp restore $DB từ: $FILE"
echo "⚠️  CẢNH BÁO: Dữ liệu hiện tại sẽ bị ghi đè."
read -p "Tiếp tục? (gõ 'yes' để xác nhận): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Đã huỷ."
  exit 0
fi

# ============ RESTORE ============
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
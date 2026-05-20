#!/bin/bash
# Setup script: cài rclone, đăng ký cron job
# Chạy 1 lần khi setup VPS mới

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "========================================"
echo "  Setup backup system"
echo "========================================"
echo ""

# ============ CHECK .env ============
if [ ! -f "$REPO_ROOT/.env" ]; then
  echo "ERROR: Chưa có file $REPO_ROOT/.env"
  echo ""
  echo "Hãy chạy:"
  echo "  cp $REPO_ROOT/.env.example $REPO_ROOT/.env"
  echo "  nano $REPO_ROOT/.env       # điền password và config"
  echo ""
  echo "Rồi chạy lại setup.sh"
  exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

echo "✓ Tìm thấy .env"

# ============ CHECK DOCKER ============
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker chưa được cài. Cài Docker trước."
  exit 1
fi

# Check containers đang chạy
echo ""
echo "Kiểm tra containers..."
for container in "$MYSQL_CONTAINER" "$MONGO_CONTAINER" "$POSTGRES_CONTAINER" "$REDIS_CONTAINER"; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    echo "  ✓ $container đang chạy"
  else
    echo "  ✗ $container KHÔNG chạy"
    echo ""
    echo "Hãy chạy 'docker compose up -d' trước."
    exit 1
  fi
done

# ============ CÀI RCLONE ============
echo ""
if command -v rclone &> /dev/null; then
  echo "✓ rclone đã cài: $(rclone version | head -1)"
else
  echo "Cài rclone..."
  curl https://rclone.org/install.sh | sudo bash
fi

# ============ CHECK RCLONE REMOTE ============
echo ""
REMOTE_NAME="${RCLONE_REMOTE%%:*}"   # lấy phần trước dấu ":"
if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
  echo "✓ Remote rclone '$REMOTE_NAME' đã có"
else
  echo "✗ Chưa cấu hình remote '$REMOTE_NAME'"
  echo ""
  echo "Hãy chạy 'rclone config' để setup Google Drive remote tên '$REMOTE_NAME'."
  echo "Xem hướng dẫn chi tiết trong backup/README.md"
  exit 1
fi

# ============ TEST RCLONE ============
echo ""
echo "Test kết nối Google Drive..."
if rclone lsd "$RCLONE_REMOTE" &>/dev/null; then
  echo "✓ Kết nối Drive OK"
else
  echo "Tạo folder $RCLONE_REMOTE..."
  rclone mkdir "$RCLONE_REMOTE"
fi

# ============ CẤP QUYỀN SCRIPT ============
chmod +x "$SCRIPT_DIR/backup.sh" "$SCRIPT_DIR/restore.sh"
echo "✓ Đã cấp quyền execute cho scripts"

# ============ ĐĂNG KÝ CRON ============
echo ""
CRON_LINE="${CRON_MINUTE:-0} ${CRON_HOUR:-4} * * * $SCRIPT_DIR/backup.sh >> $REPO_ROOT/backup/backup.log 2>&1"
CRON_PATH="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Lấy crontab hiện tại (nếu có)
EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")

# Check đã có job backup chưa
if echo "$EXISTING_CRON" | grep -F "$SCRIPT_DIR/backup.sh" > /dev/null; then
  echo "✓ Cron job đã tồn tại, bỏ qua"
else
  # Thêm PATH nếu chưa có
  if ! echo "$EXISTING_CRON" | grep -q "^PATH="; then
    NEW_CRON="$CRON_PATH
$EXISTING_CRON
# Backup DB (added by setup.sh)
$CRON_LINE"
  else
    NEW_CRON="$EXISTING_CRON
# Backup DB (added by setup.sh)
$CRON_LINE"
  fi
  echo "$NEW_CRON" | crontab -
  echo "✓ Đã đăng ký cron: chạy lúc ${CRON_HOUR:-4}:$(printf '%02d' ${CRON_MINUTE:-0}) hàng ngày"
fi

# ============ DONE ============
echo ""
echo "========================================"
echo "  Setup hoàn tất!"
echo "========================================"
echo ""
echo "Các bước tiếp theo:"
echo ""
echo "1. Chạy thử backup tay 1 lần để verify:"
echo "   $SCRIPT_DIR/backup.sh"
echo ""
echo "2. Xem cron đã đăng ký:"
echo "   crontab -l"
echo ""
echo "3. Theo dõi log:"
echo "   tail -f $REPO_ROOT/backup/backup.log"
echo ""
echo "4. Khi cần restore:"
echo "   $SCRIPT_DIR/restore.sh <mysql|mongo|pg|redis> <file>"
echo ""
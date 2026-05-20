#!/bin/bash
# Bootstrap script: setup VPS mới từ A-Z
# Chạy 1 lần sau khi clone repo
#
# Usage: ./backup/scripts/bootstrap.sh

set -euo pipefail

# ============ ĐỊNH VỊ ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# ============ MÀU SẮC ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()   { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()     { echo -e "${GREEN}✓${NC}  $1"; }
log_warn()   { echo -e "${YELLOW}⚠${NC}  $1"; }
log_error()  { echo -e "${RED}✗${NC}  $1"; }
log_step()   { echo ""; echo -e "${BLUE}═══ $1 ═══${NC}"; }
log_action() { echo -e "${YELLOW}→${NC}  $1"; }

pause() { read -p "$(echo -e "${YELLOW}Enter để tiếp tục...${NC}")"; }

ask_yn() {
  local prompt="$1"
  local default="${2:-y}"
  local answer
  if [ "$default" = "y" ]; then
    read -p "$(echo -e "${YELLOW}?${NC}  $prompt [Y/n]: ")" answer
    answer="${answer:-y}"
  else
    read -p "$(echo -e "${YELLOW}?${NC}  $prompt [y/N]: ")" answer
    answer="${answer:-n}"
  fi
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ============ CẤU HÌNH HARDCODE ============
CERTBOT_EMAIL="dangph.ptit@gmail.com"

DOMAINS=(
  "api.ngocrongdark.com"
  "data.ngocrongdark.com"
  "pay.ngocrongdark.com"
  "redis.ngocrongdark.com"
  "postgres.ngocrongdark.com"
  "api.dangpham.id.vn"
  "data.dangpham.id.vn"
  "pay.dangpham.id.vn"
  "redis.dangpham.id.vn"
  "postgres.dangpham.id.vn"
  "download.ngocrongdark.com"
  "ws.dangpham.id.vn"
  "ws-go.dangpham.id.vn"
)

WHITELIST_IPS=(
  "103.116.52.222"
  "103.116.52.219"
)

# Port DB cho whitelist (mysql, redis, postgres, rabbitmq, mongo)
WHITELIST_PORTS=(
  "33306"
  "36379"
  "35432"
  "35674"
  "37017"
)

# ============ CHECK ROOT ============
if [ "$EUID" -ne 0 ]; then
  log_error "Script này phải chạy với quyền root."
  log_warn "Chạy: sudo $0"
  exit 1
fi

# ============ BANNER ============
clear
cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       BOOTSTRAP - dragonboy-nginx-service                ║
║                                                          ║
║  Script tự động setup VPS mới từ A-Z:                    ║
║    1. Cài tool cơ bản (curl, git, htpasswd...)           ║
║    2. Set timezone Asia/Ho_Chi_Minh                      ║
║    3. Tạo swap 2GB                                       ║
║    4. Cài Docker                                         ║
║    5. Cấu hình UFW firewall                              ║
║    6. Tạo file .env (yêu cầu user điền)                  ║
║    7. Tạo htpasswd cho nginx                             ║
║    8. Cài certbot + lấy SSL cho 13 domain                ║
║    9. Setup auto-renewal SSL                             ║
║   10. docker compose up -d                               ║
║   11. Cài rclone + cấu hình Google Drive (OAuth)         ║
║   12. Logrotate                                          ║
║   13. Đăng ký cron backup                                ║
║                                                          ║
║  Thời gian: ~15-20 phút                                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""
log_info "Repo: $REPO_ROOT"
log_info "Email certbot: $CERTBOT_EMAIL"
log_info "Số domain SSL: ${#DOMAINS[@]}"
log_info "IP whitelist UFW: ${WHITELIST_IPS[*]}"
echo ""
log_warn "QUAN TRỌNG: Trước khi tiếp tục, đảm bảo ${#DOMAINS[@]} domain đã trỏ về IP VPS này."
echo ""

if ! ask_yn "Bắt đầu setup?"; then
  log_warn "Đã huỷ."
  exit 0
fi

# ============ BƯỚC 1: CÀI TOOL CƠ BẢN ============
log_step "Bước 1/13: Cài tool cơ bản"

log_action "apt update..."
apt update -qq

log_action "Cài các tool cần thiết..."
apt install -y -qq \
  curl wget git \
  vim nano \
  htop ncdu \
  net-tools dnsutils \
  unzip zip \
  jq \
  apache2-utils \
  ca-certificates \
  gnupg \
  lsb-release

log_ok "Đã cài tool cơ bản"

# ============ BƯỚC 2: TIMEZONE ============
log_step "Bước 2/13: Set timezone"

CURRENT_TZ=$(timedatectl show --property=Timezone --value)
if [ "$CURRENT_TZ" = "Asia/Ho_Chi_Minh" ]; then
  log_ok "Timezone đã đúng: Asia/Ho_Chi_Minh"
else
  log_action "Đổi timezone từ $CURRENT_TZ → Asia/Ho_Chi_Minh..."
  timedatectl set-timezone Asia/Ho_Chi_Minh
  log_ok "Timezone: $(timedatectl show --property=Timezone --value)"
fi

# ============ BƯỚC 3: SWAP ============
log_step "Bước 3/13: Tạo swap"

if [ -f /swapfile ] || swapon --show | grep -q "/swapfile"; then
  log_ok "Swap đã tồn tại"
  swapon --show
else
  log_action "Tạo swap 2GB..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  if ! grep -q "/swapfile" /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  log_ok "Đã tạo swap 2GB"
  swapon --show
fi

# ============ BƯỚC 4: DOCKER ============
log_step "Bước 4/13: Docker"

if command -v docker &> /dev/null && docker compose version &> /dev/null; then
  log_ok "Docker đã cài: $(docker --version)"
  log_ok "Docker Compose: $(docker compose version | head -1)"
else
  log_action "Cài Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  log_ok "Đã cài Docker"
fi

# ============ BƯỚC 5: UFW ============
log_step "Bước 5/13: UFW Firewall"

if ! command -v ufw &> /dev/null; then
  log_action "Cài UFW..."
  apt install -y -qq ufw
fi

UFW_STATUS=$(ufw status | head -1)
if echo "$UFW_STATUS" | grep -q "Status: active"; then
  log_warn "UFW đã active rồi. Bỏ qua cấu hình mới."
  log_info "Nếu muốn cấu hình lại, chạy: ufw --force reset"
else
  log_action "Cấu hình UFW..."

  ufw default deny incoming
  ufw default allow outgoing

  # SSH/HTTP/HTTPS — CỰC KỲ QUAN TRỌNG
  ufw allow 22/tcp comment 'SSH'
  ufw allow 80/tcp comment 'HTTP'
  ufw allow 443/tcp comment 'HTTPS'

  # Port DB whitelist cho VPS2, VPS3
  for ip in "${WHITELIST_IPS[@]}"; do
    for port in "${WHITELIST_PORTS[@]}"; do
      ufw allow from "$ip" to any port "$port" comment "DB-$ip"
    done
  done

  log_action "Enable UFW..."
  ufw --force enable
  log_ok "UFW đã active"
  ufw status numbered
fi

# ============ BƯỚC 6: .ENV ============
log_step "Bước 6/13: File .env"

if [ -f "$REPO_ROOT/.env" ]; then
  log_ok "File .env đã tồn tại"
  if ask_yn "Mở .env để chỉnh sửa lại?" "n"; then
    nano "$REPO_ROOT/.env"
  fi
else
  if [ ! -f "$REPO_ROOT/.env.example" ]; then
    log_error "Không tìm thấy .env.example!"
    exit 1
  fi
  log_action "Copy .env.example → .env..."
  cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
  chmod 600 "$REPO_ROOT/.env"
  log_ok "Đã tạo .env"
  echo ""
  log_warn "Mở nano để bạn điền:"
  echo "    - MYSQL_PASS, MONGO_PASS"
  echo "    - HTPASSWD_USER, HTPASSWD_PASS"
  echo "    - Các config khác (mặc định OK)"
  echo ""
  log_warn "Password có ký tự đặc biệt (@, \$, !) phải bọc nháy đơn:"
  echo "    MYSQL_PASS='Phamhaidang112@'"
  echo ""
  pause
  nano "$REPO_ROOT/.env"
fi

# Verify .env load được
if ! ( set -a; source "$REPO_ROOT/.env"; set +a ) 2>/dev/null; then
  log_error ".env có lỗi cú pháp."
  exit 1
fi

set -a
source "$REPO_ROOT/.env"
set +a

# Validate biến cần thiết
REQUIRED_VARS=(MYSQL_PASS MONGO_PASS HTPASSWD_USER HTPASSWD_PASS RCLONE_REMOTE)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ] || [[ "${!var}" =~ ^changeme ]]; then
    log_error "Biến $var trong .env chưa được điền."
    exit 1
  fi
done

log_ok ".env load OK, đã validate"

# ============ BƯỚC 7: HTPASSWD ============
log_step "Bước 7/13: Tạo htpasswd"

if [ -f "$REPO_ROOT/htpasswd" ]; then
  log_action "Xoá htpasswd cũ..."
  rm -f "$REPO_ROOT/htpasswd"
fi

htpasswd -bc "$REPO_ROOT/htpasswd" "$HTPASSWD_USER" "$HTPASSWD_PASS"
chmod 600 "$REPO_ROOT/htpasswd"
log_ok "Đã tạo htpasswd với user '$HTPASSWD_USER'"

# ============ BƯỚC 8: CERTBOT + SSL ============
log_step "Bước 8/13: Certbot + SSL"

if ! command -v certbot &> /dev/null; then
  log_action "Cài certbot..."
  apt install -y -qq certbot
fi

# Check cert hiện có
EXISTING_CERT=""
if [ -f "/etc/letsencrypt/live/${DOMAINS[0]}/fullchain.pem" ]; then
  EXISTING_CERT="/etc/letsencrypt/live/${DOMAINS[0]}/fullchain.pem"
  EXPIRY=$(openssl x509 -enddate -noout -in "$EXISTING_CERT" | cut -d= -f2)
  log_ok "Cert đã tồn tại, hết hạn: $EXPIRY"
  if ! ask_yn "Lấy cert mới?" "n"; then
    log_info "Skip certbot."
  else
    EXISTING_CERT=""
  fi
fi

if [ -z "$EXISTING_CERT" ]; then
  log_warn "Sẽ dừng container nginx (nếu đang chạy) để certbot dùng port 80..."
  docker stop nginx 2>/dev/null || true

  log_action "Chạy certbot cho ${#DOMAINS[@]} domain..."
  CERTBOT_DOMAINS=""
  for d in "${DOMAINS[@]}"; do
    CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d $d"
  done

  certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$CERTBOT_EMAIL" \
    $CERTBOT_DOMAINS

  log_ok "Đã lấy SSL cho ${#DOMAINS[@]} domain"
fi

# ============ BƯỚC 9: AUTO-RENEWAL SSL ============
log_step "Bước 9/13: Setup auto-renewal SSL"

RENEW_CRON="0 3 * * * certbot renew --quiet --deploy-hook 'docker exec nginx nginx -s reload 2>/dev/null || true'"

if crontab -l 2>/dev/null | grep -q "certbot renew"; then
  log_ok "Cron renewal đã có"
else
  EXISTING_CRON=$(crontab -l 2>/dev/null || echo "")
  NEW_CRON="$EXISTING_CRON
# Auto-renew SSL hàng ngày 3h sáng
$RENEW_CRON"
  echo "$NEW_CRON" | crontab -
  log_ok "Đã đăng ký cron auto-renewal (3h sáng hàng ngày)"
fi

log_action "Test dry-run renewal..."
if certbot renew --dry-run 2>&1 | tail -5 | grep -q "Congratulations\|success\|no renewals"; then
  log_ok "Dry-run renewal OK"
else
  log_warn "Dry-run renewal có warning, check kỹ"
fi

# ============ BƯỚC 10: DOCKER COMPOSE UP ============
log_step "Bước 10/13: Bật docker-compose"

cd "$REPO_ROOT"

# Verify docker-compose.yml tồn tại
if [ ! -f "docker-compose.yml" ]; then
  log_error "Không tìm thấy docker-compose.yml"
  exit 1
fi

log_action "docker compose up -d..."
docker compose up -d

log_action "Đợi 20s cho DB init..."
sleep 20

log_info "Trạng thái containers:"
docker ps --format "table {{.Names}}\t{{.Status}}"

# Verify 4 DB containers
echo ""
for container in "${MYSQL_CONTAINER:-mysql-nro}" "${MONGO_CONTAINER:-mongo}" "${POSTGRES_CONTAINER:-postgres}" "${REDIS_CONTAINER:-redis}"; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    log_ok "$container đang chạy"
  else
    log_error "$container KHÔNG chạy"
    log_warn "Check log: docker compose logs $container"
    exit 1
  fi
done

# ============ BƯỚC 11: RCLONE ============
log_step "Bước 11/13: Rclone"

if command -v rclone &> /dev/null; then
  log_ok "rclone đã cài: $(rclone version | head -1)"
else
  log_action "Cài rclone..."
  curl https://rclone.org/install.sh | sudo bash
fi

REMOTE_NAME="${RCLONE_REMOTE%%:*}"

if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
  log_ok "Remote '$REMOTE_NAME' đã được cấu hình"

  if rclone lsd "${REMOTE_NAME}:" &>/dev/null; then
    log_ok "Kết nối Drive OK"
  else
    log_warn "Test kết nối fail. Token có thể hết hạn."
    if ask_yn "Reconnect ngay?"; then
      rclone config reconnect "${REMOTE_NAME}:"
    fi
  fi
else
  log_warn "Chưa có remote '$REMOTE_NAME'"
  cat <<EOF

${YELLOW}═══════════════════════════════════════════════════════════${NC}
${YELLOW}HƯỚNG DẪN CẤU HÌNH RCLONE (CẦN MÁY LOCAL CÓ BROWSER):${NC}

Khi mở rclone config, trả lời:
  1.  n (new remote)
  2.  name: ${GREEN}${REMOTE_NAME}${NC}
  3.  Storage: ${GREEN}drive${NC}
  4.  client_id: Enter
  5.  client_secret: Enter
  6.  scope: ${GREEN}1${NC}
  7.  service_account_file: Enter
  8.  Edit advanced: ${GREEN}n${NC}
  9.  Use web browser: ${GREEN}n${NC}
  10. Copy lệnh ${GREEN}rclone authorize "drive" "..."${NC}
      → Chạy trên máy local có browser
      → Browser mở, login Google, Allow
      → Copy chuỗi JSON về paste vào đây
  11. Shared Drive: ${GREEN}n${NC}
  12. Keep: ${GREEN}y${NC}
  13. Quit: ${GREEN}q${NC}

Trên Windows tải rclone tại: https://rclone.org/downloads/
${YELLOW}═══════════════════════════════════════════════════════════${NC}

EOF
  pause
  rclone config

  if ! rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
    log_error "Vẫn chưa có remote. Hãy chạy lại bootstrap.sh"
    exit 1
  fi
  log_ok "Đã cấu hình rclone"
fi

rclone mkdir "$RCLONE_REMOTE" 2>/dev/null || true
log_ok "Folder Drive sẵn sàng"

# ============ BƯỚC 12: LOGROTATE ============
log_step "Bước 12/13: Logrotate"

LOGROTATE_CONF="/etc/logrotate.d/db-backup"

cat > "$LOGROTATE_CONF" <<EOF
$REPO_ROOT/backup/backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF

log_ok "Đã setup logrotate (rotate weekly, giữ 4 tuần)"

# ============ BƯỚC 13: SETUP CRON BACKUP ============
log_step "Bước 13/13: Setup cron backup"

if [ ! -x "$SCRIPT_DIR/setup.sh" ]; then
  chmod +x "$SCRIPT_DIR"/*.sh
fi

"$SCRIPT_DIR/setup.sh"

# ============ HOÀN TẤT ============
echo ""
echo ""
cat <<EOF
${GREEN}╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              ✓ BOOTSTRAP HOÀN TẤT                        ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝${NC}

${BLUE}Đã setup:${NC}
  ✓ Tool cơ bản (curl, git, htpasswd, dig...)
  ✓ Timezone Asia/Ho_Chi_Minh
  ✓ Swap 2GB
  ✓ Docker + Docker Compose
  ✓ UFW firewall (port 22, 80, 443, DB ports cho IP whitelist)
  ✓ .env (chmod 600)
  ✓ htpasswd (user: ${HTPASSWD_USER})
  ✓ SSL cho ${#DOMAINS[@]} domain
  ✓ Auto-renew SSL (3h sáng hàng ngày)
  ✓ docker-compose stack đang chạy
  ✓ rclone + Google Drive
  ✓ Logrotate cho backup.log
  ✓ Cron backup DB (${CRON_HOUR:-4}:$(printf '%02d' "${CRON_MINUTE:-0}") hàng ngày)

${BLUE}Các bước tiếp theo (khuyến nghị):${NC}

1. ${YELLOW}Test backup tay:${NC}
   $SCRIPT_DIR/backup.sh

2. ${YELLOW}Test các domain HTTPS:${NC}
   curl -I https://${DOMAINS[0]}

3. ${YELLOW}Xem cron đã đăng ký:${NC}
   crontab -l

4. ${YELLOW}Theo dõi log:${NC}
   tail -f $REPO_ROOT/backup/backup.log

5. ${YELLOW}Khi cần restore:${NC}
   $SCRIPT_DIR/restore.sh <mysql|mongo|pg|redis> <file>

${YELLOW}LƯU Ý:${NC}
  - DNS của ${#DOMAINS[@]} domain đã trỏ về IP VPS này.
  - Nếu chưa, sửa DNS rồi chạy lại certbot.
  - Tài liệu chi tiết: $REPO_ROOT/backup/BACKUP_RESTORE_GUIDE.md

EOF

if ask_yn "Chạy backup ngay bây giờ để verify?"; then
  echo ""
  "$SCRIPT_DIR/backup.sh"
fi

log_ok "Xong. VPS đã sẵn sàng phục vụ."
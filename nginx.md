# Let's Encrypt dùng DNS để tìm đường đến server của bạn
#         │
#         ▼
# DNS trỏ yourdomain.com → 1.2.3.4
#         │
#         ▼
# Let's Encrypt đến 1.2.3.4 để kiểm tra file xác minh
#         │
#         ▼
# Tìm thấy file → cấp cert

# cấp xong 
# Cert nói: "Vào ngày 19/03/2026, server này đã chứng minh
#            họ kiểm soát yourdomain.com"

# phải xác minh cả 2 phía, 
# Chiều 1 — DNS: domain → IP
# Admin cấu hình ngocrongdark.com → 103.xxx.xxx.xx
# → Ai cũng làm được, kể cả hacker

# Chiều 2 — Cert: server chứng minh sở hữu domain
# Server 103.xxx.xxx.xx chứng minh mình là ngocrongdark.com
# → Chỉ admin thật sự kiểm soát server mới làm được

# Hacker mua domain: ngocrongdark.com-fake.com
# Trỏ DNS về IP của bạn: 103.xxx.xxx.xx
# User gõ ngocrongdark.com-fake.com
# → Đến đúng server của bạn
# → Nhưng user tưởng đang ở trang fake

# Cert BẢO VỆ khỏi:
# → Man in the middle (nghe lén giữa đường)
# → Dữ liệu bị đọc/sửa khi truyền
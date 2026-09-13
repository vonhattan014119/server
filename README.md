# Paper 26.2 Server — bật/tắt theo yêu cầu, qua GitHub hoặc Discord

Server **không tự chạy theo giờ nữa**. Ai đó bấm Start thì nó mới mở, bấm Stop thì tắt (tự lưu world), bấm Restart thì khởi động lại (world giữ nguyên).

---

## PHẦN 1 — Thiết lập cơ bản (bắt buộc, làm trước)

1. Tạo 1 repo GitHub mới, để **Public** (để không bị giới hạn phút chạy Actions).
2. Upload toàn bộ nội dung thư mục này lên repo, giữ nguyên cấu trúc thư mục.
3. Vào **https://playit.gg** → tạo tài khoản miễn phí → tạo 1 Agent → lấy **Secret Key**.
4. Trong repo GitHub → **Settings → Secrets and variables → Actions → New repository secret**:
   - Tên: `PLAYIT_SECRET_KEY` → dán secret key vừa lấy.
5. Trên playit.gg, tạo 1 tunnel loại **Minecraft Java** trỏ tới cổng `25565`. Nó cho bạn 1 địa chỉ dạng `abc123.joinmc.link` — **địa chỉ này cố định vĩnh viễn**, gửi cho bạn bè dùng để kết nối.
6. Vào tab **Actions** của repo, bật Actions nếu đang tắt.

Tới đây là đã dùng được **Cách 1** bên dưới rồi.

---

## Cách 1 — Bấm trực tiếp trên GitHub (không cần làm gì thêm)

- **Mở server**: Vào tab **Actions** → chọn workflow **"Paper 26.2 On-Demand Server"** → nút **Run workflow** → Run.
- **Tắt / Khởi động lại**: Vào tab **Actions** → chọn workflow **"MC Server Control"** → **Run workflow** → chọn `stop` hoặc `restart` → Run.
- Muốn bạn bè cũng bấm được: thêm họ làm **Collaborator** trong Settings → Collaborators, hoặc dùng app GitHub trên điện thoại cũng bấm được y hệt.

---

## Cách 2 — Bật/tắt bằng lệnh chat Discord `/start /stop /restart`

Phần này cần thiết lập 1 lần (~15-20 phút), sau đó dùng mãi mãi, miễn phí hoàn toàn.

### Bước 1: Tạo Discord Application
1. Vào https://discord.com/developers/applications → **New Application**, đặt tên tùy ý.
2. Trong tab **General Information**, ghi lại **Application ID** và **Public Key**.
3. Trong tab **Bot** → **Reset Token** → ghi lại **Bot Token** (chỉ hiện 1 lần).
4. Vẫn trong tab **Bot**, dùng URL Generator (tab **OAuth2 → URL Generator**), tick scope `applications.commands`, lấy link mời bot vào server Discord của bạn.

### Bước 2: Tạo Personal Access Token của GitHub (để bot gọi được API)
1. Vào https://github.com/settings/tokens?type=beta → **Generate new token** (loại Fine-grained).
2. Chọn đúng repo server Minecraft của bạn, quyền **Actions: Read and write**.
3. Lưu token lại (dạng `github_pat_...`).

### Bước 3: Deploy Cloudflare Worker (miễn phí)
```bash
cd discord-bot
npm install
npx wrangler login
```
Sửa file `wrangler.toml`, đổi `GH_REPO` thành `ten-tai-khoan/ten-repo` của bạn.

Set 2 secret:
```bash
npx wrangler secret put DISCORD_PUBLIC_KEY
# dán Public Key ở Bước 1

npx wrangler secret put GH_TOKEN
# dán Personal Access Token ở Bước 2
```

Deploy:
```bash
npx wrangler deploy
```
Sau khi deploy xong, Cloudflare sẽ cho bạn 1 URL dạng `https://mc-discord-bot.<ten-cua-ban>.workers.dev`.

### Bước 4: Gắn URL đó vào Discord
1. Quay lại Discord Developer Portal → tab **General Information**.
2. Ô **Interactions Endpoint URL** → dán URL Cloudflare Worker ở Bước 3 → Save.

### Bước 5: Đăng ký 3 lệnh slash command
```bash
cd discord-bot
DISCORD_APP_ID=xxxx DISCORD_BOT_TOKEN=xxxx node register-commands.js
```
Đợi khoảng 1 phút, mở Discord lên, gõ `/start`, `/stop`, `/restart` trong server đã mời bot vào là dùng được.

---

## Cách hoạt động phía sau
- File `command.txt` trên 1 branch riêng tên `control` đóng vai trò "hộp thư" — server đang chạy tự kiểm tra hộp thư này mỗi 30 giây để biết có ai bấm Stop/Restart không.
- World được nén và lưu vào branch `world-data` mỗi khi tắt/restart, và tự khôi phục lại ở lần mở tiếp theo — chơi tiếp đúng chỗ cũ, không mất đồ.
- Có mốc an toàn tự tắt sau 5h40 mỗi phiên (dưới giới hạn 6 tiếng/job của GitHub Actions) — nếu quên bấm Stop thì máy tự lưu và tắt, không bị lỗi giữa chừng.
- 2 workflow (Start và Control) độc lập nhau, nên bấm trên GitHub hay gõ lệnh Discord đều tác động cùng 1 server, không xung đột.

## Lưu ý
- **Rủi ro điều khoản dịch vụ:** GitHub Actions thiết kế cho CI/CD, không phải để host server dài hạn. Dùng theo kiểu bật/tắt vài tiếng mỗi lần như thế này rủi ro thấp, nhưng vẫn không phải cách dùng "chính thống" — nếu cần độ ổn định tuyệt đối lâu dài, cân nhắc VPS giá rẻ/miễn phí (Oracle Cloud Free Tier).
- `online-mode=true` trong `server.properties` nghĩa là chỉ tài khoản Minecraft bản quyền vào được. Đổi `false` nếu bạn bè dùng bản crack (nhưng khi đó ai cũng giả tên người khác được).
- RAM mặc định 3GB, có thể chỉnh trong `scripts/run-session.sh` nếu cần.

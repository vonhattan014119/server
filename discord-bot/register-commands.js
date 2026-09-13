// Chạy 1 lần bằng: node register-commands.js
// Cần set biến môi trường DISCORD_APP_ID và DISCORD_BOT_TOKEN trước khi chạy

const commands = [
  { name: 'start', description: 'Mở server Minecraft' },
  { name: 'stop', description: 'Tắt server Minecraft (tự lưu world)' },
  { name: 'restart', description: 'Khởi động lại server Minecraft (giữ nguyên world)' },
];

const APP_ID = process.env.DISCORD_APP_ID;
const TOKEN = process.env.DISCORD_BOT_TOKEN;

if (!APP_ID || !TOKEN) {
  console.error('Thiếu DISCORD_APP_ID hoặc DISCORD_BOT_TOKEN trong biến môi trường.');
  process.exit(1);
}

fetch(`https://discord.com/api/v10/applications/${APP_ID}/commands`, {
  method: 'PUT',
  headers: {
    Authorization: `Bot ${TOKEN}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(commands),
})
  .then((r) => r.json())
  .then((data) => console.log('Đã đăng ký lệnh:', data))
  .catch((err) => console.error('Lỗi:', err));

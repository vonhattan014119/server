#!/usr/bin/env bash
set -euo pipefail

MAX_SECONDS=$((5*3600 + 40*60))   # mốc an toàn 5h40, dưới giới hạn 6 tiếng/job của GitHub
POLL_SECONDS=30                    # tần suất kiểm tra lệnh điều khiển
START_TS=$(date +%s)
LAST_CMD_TS=0

mkdir -p server
cd server

# ---------- Khôi phục world cũ (nếu có) ----------
echo ">>> Kiểm tra world cũ..."
if git ls-remote --exit-code --heads "https://github.com/${GITHUB_REPOSITORY}.git" world-data >/dev/null 2>&1; then
  git clone --depth 1 --branch world-data "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" ../world-data-repo
  if [ -f ../world-data-repo/world-backup.tar.gz ]; then
    tar xzf ../world-data-repo/world-backup.tar.gz -C .
    echo ">>> Đã khôi phục world."
  fi
else
  echo ">>> Chưa có world cũ, sẽ tạo world mới."
fi

# ---------- Tải Paper 26.2 build mới nhất ----------
echo ">>> Lấy build Paper 26.2 mới nhất..."
BUILD=$(curl -s https://api.papermc.io/v2/projects/paper/versions/26.2 | python3 -c "import sys,json;print(json.load(sys.stdin)['builds'][-1])")
curl -sSL -o paper.jar "https://api.papermc.io/v2/projects/paper/versions/26.2/builds/${BUILD}/downloads/paper-26.2-${BUILD}.jar"
echo "eula=true" > eula.txt

if [ ! -f server.properties ]; then
  cat > server.properties <<'EOF'
server-port=25565
online-mode=true
motd=Server cua ban - Paper 26.2
max-players=10
view-distance=8
EOF
fi

# ---------- Mở tunnel playit.gg (địa chỉ kết nối cố định) ----------
echo ">>> Mở tunnel playit.gg..."
curl -sSL https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64 -o playit
chmod +x playit
./playit --secret "${PLAYIT_SECRET_KEY}" &
PLAYIT_PID=$!

start_mc() {
  java -Xms3G -Xmx3G --add-modules=jdk.incubator.vector -XX:+UseG1GC -jar paper.jar --nogui &
  MC_PID=$!
  echo ">>> Server đã khởi động (PID $MC_PID)"
}

stop_mc_gracefully() {
  echo ">>> Đang tắt server để lưu world an toàn..."
  kill -SIGTERM "$MC_PID" 2>/dev/null || true
  wait "$MC_PID" 2>/dev/null || true
}

save_world() {
  echo ">>> Đang lưu world lên branch world-data..."
  cd ..
  rm -rf world-data-repo
  git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" world-data-repo
  cd world-data-repo
  git checkout world-data 2>/dev/null || git checkout --orphan world-data
  git rm -rf . >/dev/null 2>&1 || true
  tar czf world-backup.tar.gz -C ../server world world_nether world_the_end server.properties 2>/dev/null || true
  git add world-backup.tar.gz
  git -c user.name="mc-bot" -c user.email="mc-bot@users.noreply.github.com" commit -m "Backup $(date -u +%F_%H-%M)" || echo "Không có gì thay đổi"
  git push -f origin world-data
  cd ../server
}

fetch_control() {
  rm -rf ../control-repo
  git clone --depth 1 --branch control "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" ../control-repo 2>/dev/null || true
}

# ---------- Khởi động server lần đầu ----------
start_mc

echo ">>> Server đang chạy. Đợi lệnh Stop/Restart hoặc tới mốc an toàn ${MAX_SECONDS}s..."
while true; do
  sleep "$POLL_SECONDS"

  ELAPSED=$(( $(date +%s) - START_TS ))
  if [ "$ELAPSED" -ge "$MAX_SECONDS" ]; then
    echo ">>> Đạt mốc an toàn, tự tắt để tránh vượt giới hạn GitHub Actions."
    break
  fi

  fetch_control
  if [ -f ../control-repo/command.txt ]; then
    CMD_LINE=$(cat ../control-repo/command.txt)
    CMD_TYPE=${CMD_LINE%%:*}
    CMD_TS=${CMD_LINE##*:}
    if [ "$CMD_TS" != "$LAST_CMD_TS" ]; then
      LAST_CMD_TS=$CMD_TS
      if [ "$CMD_TYPE" == "STOP" ]; then
        echo ">>> Nhận lệnh STOP."
        break
      elif [ "$CMD_TYPE" == "RESTART" ]; then
        echo ">>> Nhận lệnh RESTART."
        stop_mc_gracefully
        save_world
        start_mc
      fi
    fi
  fi
done

stop_mc_gracefully
kill "$PLAYIT_PID" 2>/dev/null || true
save_world
echo ">>> Xong phiên chơi."

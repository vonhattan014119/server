import { verifyKey, InteractionType, InteractionResponseType } from 'discord-interactions';

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('MC Discord bot đang hoạt động.');
    }

    const signature = request.headers.get('x-signature-ed25519');
    const timestamp = request.headers.get('x-signature-timestamp');
    const body = await request.text();

    const isValid = signature && timestamp &&
      (await verifyKey(body, signature, timestamp, env.DISCORD_PUBLIC_KEY));
    if (!isValid) {
      return new Response('Chữ ký không hợp lệ', { status: 401 });
    }

    const interaction = JSON.parse(body);

    if (interaction.type === InteractionType.PING) {
      return json({ type: InteractionResponseType.PONG });
    }

    if (interaction.type === InteractionType.APPLICATION_COMMAND) {
      const cmd = interaction.data.name;
      if (cmd === 'start') return handleStart(env);
      if (cmd === 'stop') return handleControl(env, 'stop');
      if (cmd === 'restart') return handleControl(env, 'restart');
    }

    return json({ type: 4, data: { content: 'Lệnh không rõ.' } });
  },
};

function json(obj) {
  return new Response(JSON.stringify(obj), {
    headers: { 'content-type': 'application/json' },
  });
}

function githubHeaders(env) {
  return {
    Authorization: `Bearer ${env.GH_TOKEN}`,
    Accept: 'application/vnd.github+json',
    'User-Agent': 'mc-discord-bot',
  };
}

async function handleStart(env) {
  // Kiểm tra xem đã có phiên nào đang chạy chưa, tránh mở trùng
  const runsRes = await fetch(
    `https://api.github.com/repos/${env.GH_REPO}/actions/workflows/mc-server.yml/runs?status=in_progress`,
    { headers: githubHeaders(env) }
  );
  const runsData = await runsRes.json();
  if (runsData.total_count > 0) {
    return json({ type: 4, data: { content: '⚠️ Server đang chạy rồi, không cần mở lại đâu!' } });
  }

  await fetch(
    `https://api.github.com/repos/${env.GH_REPO}/actions/workflows/mc-server.yml/dispatches`,
    {
      method: 'POST',
      headers: githubHeaders(env),
      body: JSON.stringify({ ref: 'main' }),
    }
  );

  return json({
    type: 4,
    data: { content: '🟢 Đang mở server... đợi khoảng 30-60 giây rồi vào chơi nhé!' },
  });
}

async function handleControl(env, action) {
  await fetch(
    `https://api.github.com/repos/${env.GH_REPO}/actions/workflows/control.yml/dispatches`,
    {
      method: 'POST',
      headers: githubHeaders(env),
      body: JSON.stringify({ ref: 'main', inputs: { action } }),
    }
  );

  const msg =
    action === 'stop'
      ? '🔴 Đang tắt server và lưu world, đợi ít phút nhé.'
      : '🔄 Đang khởi động lại server (world vẫn giữ nguyên).';
  return json({ type: 4, data: { content: msg } });
}

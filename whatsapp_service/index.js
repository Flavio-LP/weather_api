const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const qrcode = require('qrcode-terminal');

const app = express();
app.use(express.json());

let isReady = false;

const client = new Client({
  authStrategy: new LocalAuth({ dataPath: '/app/.wwebjs_auth' }),
  puppeteer: {
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-zygote',
      '--disable-gpu'
    ]
  }
});

client.on('qr', (qr) => {
  qrcode.generate(qr, { small: true });
  console.log('Escaneie o QR Code acima com o WhatsApp.');
});

client.on('ready', () => {
  isReady = true;
  console.log('WhatsApp conectado!');
});

client.on('disconnected', () => {
  isReady = false;
  console.log('WhatsApp desconectado.');
});

client.initialize();

app.get('/health', (_req, res) => {
  res.json({ ready: isReady });
});

app.post('/send', async (req, res) => {
  if (!isReady) {
    return res.status(503).json({ error: 'WhatsApp não está conectado' });
  }

  const { message, group_id } = req.body;
  if (!message) {
    return res.status(400).json({ error: 'Campo "message" é obrigatório' });
  }

  const targetGroup = group_id ;
  if (!targetGroup) {
    return res.status(500).json({ error: 'group_id não informado e WHATSAPP_GROUP_ID não configurado' });
  }

  try {
    const chat = await client.getChatById(targetGroup);

    if (!chat) {
      return res.status(404).json({ error: `Grupo "${targetGroup}" não encontrado` });
    }

    await chat.sendMessage(message);
    res.json({ sent: true, group: targetGroup });
  } catch (err) {
    console.error('[send]', err.message);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Serviço WhatsApp na porta ${PORT}`);
});

// Tiny TCP forwarder: Railway's edge expects a listener on 0.0.0.0:$PORT,
// while dsh web only accepts one concrete bind address, so dsh stays on
// loopback and this proxy forwards raw TCP (HTTP + WebSocket pass through).
const net = require('net');

const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = 3090;
const PORT = parseInt(process.env.PORT || '8080', 10);

function handle(client) {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST);
  const kill = () => { client.destroy(); upstream.destroy(); };
  client.on('error', kill);
  upstream.on('error', kill);
  client.pipe(upstream);
  upstream.pipe(client);
}

const v4 = net.createServer(handle);
v4.on('error', (e) => console.error('proxy v4 error:', e.message));
v4.listen(PORT, '0.0.0.0', () =>
  console.log(`proxy listening on 0.0.0.0:${PORT} -> ${TARGET_HOST}:${TARGET_PORT}`));

const v6 = net.createServer(handle);
v6.on('error', () => console.log('proxy: IPv6 listener unavailable, IPv4 only'));
v6.listen(PORT, '::', () =>
  console.log(`proxy listening on [::]:${PORT} -> ${TARGET_HOST}:${TARGET_PORT}`));

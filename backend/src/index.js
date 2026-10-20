require('dotenv').config();
require('express-async-errors');

const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');

const attachSocket = require('./socket');

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => res.json({ app: 'Zaraa Party', ok: true }));

app.use('/api', require('./routes/auth'));
app.use('/api', require('./routes/catalog'));
app.use('/api', require('./routes/shop'));
app.use('/api', require('./routes/admin'));
app.use('/api', require('./routes/rooms'));

// Penanganan error terpusat agar server tidak crash.
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Terjadi kesalahan pada server' });
});

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
attachSocket(io);

const port = process.env.PORT || 3000;
server.listen(port, () => console.log(`Zaraa Party backend berjalan di port ${port}`));

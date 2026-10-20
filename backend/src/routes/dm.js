const router = require('express').Router();
const pool = require('../db');
const { authenticate } = require('../auth');

// Daftar percakapan: pesan terakhir per lawan bicara + jumlah belum dibaca.
router.get('/dm/conversations', authenticate, async (req, res) => {
  const { rows } = await pool.query(
    `WITH last AS (
       SELECT DISTINCT ON (peer) peer, id, text, created_at, sender_id FROM (
         SELECT CASE WHEN sender_id = $1 THEN receiver_id ELSE sender_id END AS peer, id, text, created_at, sender_id
           FROM direct_messages WHERE sender_id = $1 OR receiver_id = $1
       ) m ORDER BY peer, id DESC
     )
     SELECT u.id, u.public_id, u.display_name, u.avatar_url, l.text AS last_text, l.created_at AS last_at,
            (SELECT count(*)::int FROM direct_messages d
               WHERE d.sender_id = u.id AND d.receiver_id = $1 AND d.read_at IS NULL) AS unread
       FROM last l JOIN users u ON u.id = l.peer
      ORDER BY l.id DESC LIMIT 100`,
    [req.user.id]
  );
  res.json(rows);
});

router.get('/dm/unread-count', authenticate, async (req, res) => {
  const { rows: [r] } = await pool.query(
    'SELECT count(*)::int AS n FROM direct_messages WHERE receiver_id = $1 AND read_at IS NULL',
    [req.user.id]
  );
  res.json({ unread: r.n });
});

// Riwayat dengan satu pengguna (terbaru dulu), sekaligus menandai pesan masuk sebagai terbaca.
router.get('/dm/:userId', authenticate, async (req, res) => {
  const peer = parseInt(req.params.userId, 10);
  const before = parseInt(req.query.before, 10) || 2147483647;
  const { rows } = await pool.query(
    `SELECT id, sender_id, receiver_id, text, created_at FROM direct_messages
      WHERE ((sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)) AND id < $3
      ORDER BY id DESC LIMIT 50`,
    [req.user.id, peer, before]
  );
  await pool.query(
    'UPDATE direct_messages SET read_at = now() WHERE sender_id = $1 AND receiver_id = $2 AND read_at IS NULL',
    [peer, req.user.id]
  );
  res.json(rows);
});

router.post('/dm/:userId', authenticate, async (req, res) => {
  const peer = parseInt(req.params.userId, 10);
  const text = String((req.body && req.body.text) || '').trim().slice(0, 500);
  if (!text) return res.status(400).json({ error: 'Pesan kosong' });
  if (peer === req.user.id) return res.status(400).json({ error: 'Tidak bisa mengirim pesan ke diri sendiri' });
  const { rowCount } = await pool.query('SELECT 1 FROM users WHERE id = $1 AND NOT banned', [peer]);
  if (!rowCount) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });

  const { rows: [m] } = await pool.query(
    `INSERT INTO direct_messages (sender_id, receiver_id, text) VALUES ($1, $2, $3)
     RETURNING id, sender_id, receiver_id, text, created_at`,
    [req.user.id, peer, text]
  );
  const io = req.app.get('io');
  if (io) {
    io.to(`user:${peer}`).emit('dm:new', {
      ...m,
      from: { id: req.user.id, display_name: req.user.display_name, avatar_url: req.user.avatar_url },
    });
  }
  res.status(201).json(m);
});

module.exports = router;

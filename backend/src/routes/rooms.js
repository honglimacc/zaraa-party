const router = require('express').Router();
const { AccessToken } = require('livekit-server-sdk');
const pool = require('../db');
const { authenticate, RANK } = require('../auth');

router.get('/rooms', authenticate, async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT r.*, u.display_name AS owner_name
       FROM rooms r JOIN users u ON u.id = r.owner_id
      WHERE r.is_active = TRUE ORDER BY r.created_at DESC LIMIT 50`
  );
  res.json(rows);
});

router.post('/rooms', authenticate, async (req, res) => {
  const { title, cover_url } = req.body || {};
  if (!title || !title.trim()) return res.status(400).json({ error: 'Judul room wajib diisi' });
  const { rows } = await pool.query(
    'INSERT INTO rooms (title, owner_id, cover_url) VALUES ($1, $2, $3) RETURNING *',
    [title.trim().slice(0, 60), req.user.id, cover_url || null]
  );
  res.status(201).json(rows[0]);
});

// Admin ke atas atau pemilik room boleh menutup room.
router.delete('/rooms/:id', authenticate, async (req, res) => {
  const { rows: [room] } = await pool.query('SELECT * FROM rooms WHERE id = $1', [req.params.id]);
  if (!room) return res.status(404).json({ error: 'Room tidak ditemukan' });
  if (room.owner_id !== req.user.id && RANK[req.user.role] < RANK.admin) {
    return res.status(403).json({ error: 'Akses ditolak' });
  }
  await pool.query('UPDATE rooms SET is_active = FALSE WHERE id = $1', [room.id]);
  res.json({ ok: true });
});

// Token untuk bergabung ke ruang suara LiveKit.
router.post('/rooms/:id/voice-token', authenticate, async (req, res) => {
  const { LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET } = process.env;
  if (!LIVEKIT_URL || !LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
    return res.status(501).json({ error: 'LiveKit belum dikonfigurasi di server' });
  }
  const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: String(req.user.id),
    name: req.user.display_name,
  });
  token.addGrant({
    roomJoin: true,
    room: `room-${req.params.id}`,
    canSubscribe: true,
    canPublish: true,
    canPublishData: true,
  });
  res.json({ url: LIVEKIT_URL, token: await token.toJwt() });
});

module.exports = router;

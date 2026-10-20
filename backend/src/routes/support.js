const router = require('express').Router();
const pool = require('../db');
const { authenticate, requireRole } = require('../auth');
const { getSetting } = require('./settings');

// Kontak CS (diatur Developer) + tiket milik sendiri.
router.get('/support', authenticate, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, subject, message, status, reply, created_at, replied_at FROM support_tickets WHERE user_id = $1 ORDER BY id DESC LIMIT 30',
    [req.user.id]
  );
  res.json({ contact: await getSetting('support'), tickets: rows });
});

router.post('/support/tickets', authenticate, async (req, res) => {
  const subject = String((req.body && req.body.subject) || '').trim().slice(0, 100);
  const message = String((req.body && req.body.message) || '').trim().slice(0, 2000);
  if (!subject || !message) return res.status(400).json({ error: 'Judul dan pesan wajib diisi' });
  const { rows: [open] } = await pool.query("SELECT count(*)::int AS n FROM support_tickets WHERE user_id = $1 AND status = 'open'", [req.user.id]);
  if (open.n >= 5) return res.status(429).json({ error: 'Terlalu banyak tiket yang belum dibalas' });
  const { rows: [t] } = await pool.query(
    'INSERT INTO support_tickets (user_id, subject, message) VALUES ($1, $2, $3) RETURNING *',
    [req.user.id, subject, message]
  );
  res.status(201).json(t);
});

// Admin ke atas: lihat & balas tiket.
router.get('/admin/tickets', authenticate, requireRole('admin'), async (req, res) => {
  const status = req.query.status === 'closed' ? 'closed' : 'open';
  const { rows } = await pool.query(
    `SELECT t.*, u.display_name, u.public_id FROM support_tickets t JOIN users u ON u.id = t.user_id
      WHERE t.status = $1 ORDER BY t.id DESC LIMIT 100`,
    [status]
  );
  res.json(rows);
});

router.post('/admin/tickets/:id/reply', authenticate, requireRole('admin'), async (req, res) => {
  const reply = String((req.body && req.body.reply) || '').trim().slice(0, 2000);
  if (!reply) return res.status(400).json({ error: 'Balasan kosong' });
  const { rows: [t] } = await pool.query(
    `UPDATE support_tickets SET reply = $1, status = 'closed', replied_by = $2, replied_at = now()
      WHERE id = $3 RETURNING user_id`,
    [reply, req.user.id, req.params.id]
  );
  if (!t) return res.status(404).json({ error: 'Tiket tidak ditemukan' });
  const io = req.app.get('io');
  if (io) io.to(`user:${t.user_id}`).emit('support:reply', { id: Number(req.params.id) });
  res.json({ ok: true });
});

module.exports = router;

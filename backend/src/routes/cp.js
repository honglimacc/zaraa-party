const router = require('express').Router();
const pool = require('../db');
const { authenticate } = require('../auth');

// Pasangan CP: pasangan aktif + permintaan masuk/keluar.
router.get('/cp', authenticate, async (req, res) => {
  const me = req.user.id;
  const { rows } = await pool.query(
    `SELECT c.id AS cp_id, c.status, c.created_at, c.accepted_at, c.requester_id,
            o.id AS user_id, o.public_id, o.display_name, o.avatar_url
       FROM cp_pairs c JOIN users o ON o.id = CASE WHEN c.requester_id = $1 THEN c.partner_id ELSE c.requester_id END
      WHERE c.requester_id = $1 OR c.partner_id = $1
      ORDER BY c.id DESC`,
    [me]
  );
  const out = { partner: null, incoming: [], outgoing: [] };
  for (const r of rows) {
    const item = {
      id: r.cp_id,
      since: r.accepted_at,
      created_at: r.created_at,
      user: { id: r.user_id, public_id: r.public_id, display_name: r.display_name, avatar_url: r.avatar_url },
    };
    if (r.status === 'accepted') out.partner = item;
    else if (r.requester_id === me) out.outgoing.push(item);
    else out.incoming.push(item);
  }
  res.json(out);
});

const hasPartner = async (client, userId) =>
  (await client.query("SELECT 1 FROM cp_pairs WHERE status = 'accepted' AND (requester_id = $1 OR partner_id = $1)", [userId])).rowCount > 0;

// Ajukan CP berdasarkan ID publik.
router.post('/cp/request', authenticate, async (req, res) => {
  const publicId = parseInt(req.body && req.body.public_id, 10);
  if (!publicId) return res.status(400).json({ error: 'ID tidak valid' });
  const { rows: [target] } = await pool.query('SELECT id FROM users WHERE public_id = $1 AND NOT banned', [publicId]);
  if (!target) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  if (target.id === req.user.id) return res.status(400).json({ error: 'Tidak bisa CP dengan diri sendiri' });
  if (await hasPartner(pool, req.user.id)) return res.status(409).json({ error: 'Kamu sudah punya CP' });
  if (await hasPartner(pool, target.id)) return res.status(409).json({ error: 'Pengguna itu sudah punya CP' });
  const dup = await pool.query(
    `SELECT 1 FROM cp_pairs WHERE status = 'pending'
       AND ((requester_id = $1 AND partner_id = $2) OR (requester_id = $2 AND partner_id = $1))`,
    [req.user.id, target.id]
  );
  if (dup.rowCount) return res.status(409).json({ error: 'Permintaan sudah ada' });
  await pool.query('INSERT INTO cp_pairs (requester_id, partner_id) VALUES ($1, $2)', [req.user.id, target.id]);
  const io = req.app.get('io');
  if (io) io.to(`user:${target.id}`).emit('cp:request', { from: req.user.display_name });
  res.status(201).json({ ok: true });
});

router.post('/cp/:id/accept', authenticate, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Kunci kedua pengguna agar dua permintaan tidak bisa sama-sama diterima.
    const { rows: [c] } = await client.query("SELECT * FROM cp_pairs WHERE id = $1 AND status = 'pending'", [req.params.id]);
    if (!c || c.partner_id !== req.user.id) throw Object.assign(new Error('Permintaan tidak ditemukan'), { status: 404 });
    await client.query('SELECT 1 FROM users WHERE id = ANY($1) ORDER BY id FOR UPDATE', [[c.requester_id, c.partner_id]]);
    if ((await hasPartner(client, c.requester_id)) || (await hasPartner(client, c.partner_id))) {
      throw Object.assign(new Error('Salah satu pihak sudah punya CP'), { status: 409 });
    }
    await client.query("UPDATE cp_pairs SET status = 'accepted', accepted_at = now() WHERE id = $1", [c.id]);
    await client.query(
      `DELETE FROM cp_pairs WHERE status = 'pending' AND id <> $1
         AND (requester_id IN ($2, $3) OR partner_id IN ($2, $3))`,
      [c.id, c.requester_id, c.partner_id]
    );
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    if (e.status) return res.status(e.status).json({ error: e.message });
    throw e;
  } finally {
    client.release();
  }
});

// Tolak / batalkan permintaan, atau putus CP aktif (oleh salah satu pihak).
router.delete('/cp/:id', authenticate, async (req, res) => {
  const { rowCount } = await pool.query(
    'DELETE FROM cp_pairs WHERE id = $1 AND (requester_id = $2 OR partner_id = $2)',
    [req.params.id, req.user.id]
  );
  rowCount ? res.json({ ok: true }) : res.status(404).json({ error: 'Tidak ditemukan' });
});

module.exports = router;

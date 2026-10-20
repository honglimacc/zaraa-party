const router = require('express').Router();
const pool = require('../db');
const { authenticate, requireRole, RANK, publicUser } = require('../auth');

router.use('/admin', authenticate, requireRole('admin'));

router.get('/admin/stats', async (_req, res) => {
  const { rows: [s] } = await pool.query(
    `SELECT (SELECT count(*)::int FROM users) AS users,
            (SELECT count(*)::int FROM users WHERE banned) AS banned,
            (SELECT count(*)::int FROM rooms WHERE is_active) AS rooms`
  );
  res.json(s);
});

router.get('/admin/users', async (req, res) => {
  const q = `%${(req.query.q || '').toString().toLowerCase()}%`;
  const { rows } = await pool.query(
    `SELECT * FROM users
      WHERE lower(username) LIKE $1 OR lower(display_name) LIKE $1 OR public_id::text LIKE $1
      ORDER BY created_at DESC LIMIT 50`,
    [q]
  );
  res.json(rows.map(publicUser));
});

// Admin ke atas boleh memblokir, selama targetnya berperingkat lebih rendah.
router.post('/admin/users/:id/ban', async (req, res) => {
  const { rows: [target] } = await pool.query('SELECT * FROM users WHERE id = $1', [req.params.id]);
  if (!target) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  if (RANK[target.role] >= RANK[req.user.role]) {
    return res.status(403).json({ error: 'Tidak boleh memblokir peran yang setara atau lebih tinggi' });
  }
  const banned = req.body && req.body.banned !== undefined ? !!req.body.banned : true;
  await pool.query('UPDATE users SET banned = $1 WHERE id = $2', [banned, target.id]);
  res.json({ ok: true, banned });
});

// Super Admin mengatur Admin; Developer boleh mengatur semua peran.
router.post('/admin/users/:id/role', requireRole('super_admin'), async (req, res) => {
  const { role } = req.body || {};
  if (!RANK[role]) return res.status(400).json({ error: 'Peran tidak valid' });
  const { rows: [target] } = await pool.query('SELECT * FROM users WHERE id = $1', [req.params.id]);
  if (!target) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });

  const me = RANK[req.user.role];
  const isDev = req.user.role === 'developer';
  // Selain Developer: hanya boleh mengubah peran yang lebih rendah dan memberi peran yang lebih rendah.
  if (!isDev && (RANK[target.role] >= me || RANK[role] >= me)) {
    return res.status(403).json({ error: 'Peran ini hanya bisa diatur oleh Developer' });
  }
  if (target.id === req.user.id) return res.status(400).json({ error: 'Tidak bisa mengubah peran sendiri' });

  await pool.query('UPDATE users SET role = $1 WHERE id = $2', [role, target.id]);
  res.json({ ok: true, role });
});

// Super Admin ke atas: tambah / kurangi koin pengguna (tercatat di riwayat).
router.post('/admin/users/:id/coins', requireRole('super_admin'), async (req, res) => {
  const amount = parseInt(req.body && req.body.amount, 10);
  const reason = (req.body && req.body.reason) || 'Penyesuaian oleh staff';
  if (!amount) return res.status(400).json({ error: 'Jumlah koin tidak valid' });

  const { rows } = await pool.query(
    'UPDATE users SET coins = GREATEST(coins + $1, 0) WHERE id = $2 RETURNING coins',
    [amount, req.params.id]
  );
  if (!rows[0]) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  await pool.query(
    'INSERT INTO coin_transactions (user_id, amount, reason, created_by) VALUES ($1, $2, $3, $4)',
    [req.params.id, amount, reason, req.user.id]
  );
  res.json({ ok: true, coins: rows[0].coins });
});

// Berikan lencana atau bingkai ke pengguna (Super Admin ke atas).
router.post('/admin/users/:id/grant', requireRole('super_admin'), async (req, res) => {
  const { item_type, item_id } = req.body || {};
  if (!['frame', 'badge'].includes(item_type) || !item_id) return res.status(400).json({ error: 'Data tidak valid' });
  await pool.query(
    'INSERT INTO user_items (user_id, item_type, item_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
    [req.params.id, item_type, item_id]
  );
  res.json({ ok: true });
});

module.exports = router;

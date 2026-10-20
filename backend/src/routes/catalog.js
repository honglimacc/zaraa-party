const router = require('express').Router();
const pool = require('../db');
const { authenticate, requireRole, RANK } = require('../auth');

// Semua isi aplikasi yang bisa diatur Developer. Nama kolom di-whitelist demi keamanan.
const RESOURCES = {
  banners: { table: 'banners', fields: ['title', 'image_url', 'link_url', 'sort_order', 'active'], order: 'sort_order, id' },
  gifts: { table: 'gifts', fields: ['name', 'icon_url', 'animation_url', 'price', 'active'], order: 'price, id' },
  frames: { table: 'frames', fields: ['name', 'image_url', 'price', 'active'], order: 'id' },
  badges: { table: 'badges', fields: ['name', 'icon_url', 'description', 'active'], order: 'id' },
  'vip-tiers': { table: 'vip_tiers', fields: ['name', 'kind', 'price_coins', 'duration_days', 'perks', 'badge_url', 'active'], order: 'kind, price_coins' },
  'coin-packages': { table: 'coin_packages', fields: ['name', 'coins', 'price_idr', 'active'], order: 'coins' },
};

const pickBody = (cfg, body) => {
  const out = {};
  for (const f of cfg.fields) {
    if (body[f] !== undefined) out[f] = f === 'perks' && typeof body[f] === 'object' ? JSON.stringify(body[f]) : body[f];
  }
  return out;
};

router.use('/catalog/:resource', authenticate, (req, res, next) => {
  req.cfg = RESOURCES[req.params.resource];
  return req.cfg ? next() : res.status(404).json({ error: 'Katalog tidak ditemukan' });
});

// Semua pengguna boleh melihat item aktif; staff (admin ke atas) melihat semuanya.
router.get('/catalog/:resource', async (req, res) => {
  const staff = RANK[req.user.role] >= RANK.admin;
  const { rows } = await pool.query(
    `SELECT * FROM ${req.cfg.table} ${staff ? '' : 'WHERE active = TRUE'} ORDER BY ${req.cfg.order}`
  );
  res.json(rows);
});

// Hanya Developer yang boleh mengubah isi katalog.
router.post('/catalog/:resource', requireRole('developer'), async (req, res) => {
  const data = pickBody(req.cfg, req.body || {});
  const keys = Object.keys(data);
  if (!keys.length) return res.status(400).json({ error: 'Data kosong' });
  const { rows } = await pool.query(
    `INSERT INTO ${req.cfg.table} (${keys.join(', ')})
     VALUES (${keys.map((_, i) => '$' + (i + 1)).join(', ')}) RETURNING *`,
    keys.map((k) => data[k])
  );
  res.status(201).json(rows[0]);
});

router.put('/catalog/:resource/:id', requireRole('developer'), async (req, res) => {
  const data = pickBody(req.cfg, req.body || {});
  const keys = Object.keys(data);
  if (!keys.length) return res.status(400).json({ error: 'Data kosong' });
  const { rows } = await pool.query(
    `UPDATE ${req.cfg.table} SET ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')}
     WHERE id = $${keys.length + 1} RETURNING *`,
    [...keys.map((k) => data[k]), req.params.id]
  );
  rows[0] ? res.json(rows[0]) : res.status(404).json({ error: 'Item tidak ditemukan' });
});

router.delete('/catalog/:resource/:id', requireRole('developer'), async (req, res) => {
  await pool.query(`DELETE FROM ${req.cfg.table} WHERE id = $1`, [req.params.id]);
  res.json({ ok: true });
});

module.exports = router;

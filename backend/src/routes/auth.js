const router = require('express').Router();
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { sign, authenticate, publicUser } = require('../auth');

async function uniquePublicId() {
  for (let i = 0; i < 10; i++) {
    const id = 10000000 + Math.floor(Math.random() * 89999999);
    const { rowCount } = await pool.query('SELECT 1 FROM users WHERE public_id = $1', [id]);
    if (!rowCount) return id;
  }
  throw new Error('Gagal membuat ID unik');
}

router.post('/auth/register', async (req, res) => {
  const { username, password, display_name } = req.body || {};
  if (!username || !password || password.length < 6) {
    return res.status(400).json({ error: 'Username dan password (min. 6 karakter) wajib diisi' });
  }
  const exists = await pool.query('SELECT 1 FROM users WHERE username = $1', [username.toLowerCase()]);
  if (exists.rowCount) return res.status(409).json({ error: 'Username sudah dipakai' });

  const hash = await bcrypt.hash(password, 10);
  const { rows } = await pool.query(
    `INSERT INTO users (public_id, username, display_name, password_hash)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [await uniquePublicId(), username.toLowerCase(), display_name || username, hash]
  );
  res.status(201).json({ token: sign(rows[0]), user: publicUser(rows[0]) });
});

router.post('/auth/login', async (req, res) => {
  const { username, password } = req.body || {};
  const { rows } = await pool.query('SELECT * FROM users WHERE username = $1', [(username || '').toLowerCase()]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password || '', user.password_hash))) {
    return res.status(401).json({ error: 'Username atau password salah' });
  }
  if (user.banned) return res.status(403).json({ error: 'Akun ini diblokir' });
  res.json({ token: sign(user), user: publicUser(user) });
});

// Data halaman Profil: nama, ID, Following / Fans / Visitors, koin, VIP, level, lencana.
router.get('/me', authenticate, async (req, res) => {
  const id = req.user.id;
  const [following, fans, visitors, badges, vip] = await Promise.all([
    pool.query('SELECT count(*)::int AS n FROM follows WHERE follower_id = $1', [id]),
    pool.query('SELECT count(*)::int AS n FROM follows WHERE followee_id = $1', [id]),
    pool.query('SELECT count(*)::int AS n FROM visits WHERE user_id = $1', [id]),
    pool.query("SELECT count(*)::int AS n FROM user_items WHERE user_id = $1 AND item_type = 'badge'", [id]),
    req.user.vip_tier_id
      ? pool.query('SELECT id, name, kind, badge_url FROM vip_tiers WHERE id = $1', [req.user.vip_tier_id])
      : Promise.resolve({ rows: [] }),
  ]);
  const vipActive = vip.rows[0] && req.user.vip_expires_at && new Date(req.user.vip_expires_at) > new Date();
  res.json({
    ...publicUser(req.user),
    following: following.rows[0].n,
    fans: fans.rows[0].n,
    visitors: visitors.rows[0].n,
    badge_count: badges.rows[0].n,
    vip: vipActive ? vip.rows[0] : null,
  });
});

router.get('/me/items', authenticate, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ui.id, ui.item_type, ui.item_id, ui.equipped,
            COALESCE(f.name, b.name) AS name,
            COALESCE(f.image_url, b.icon_url) AS image_url
       FROM user_items ui
       LEFT JOIN frames f ON ui.item_type = 'frame' AND f.id = ui.item_id
       LEFT JOIN badges b ON ui.item_type = 'badge' AND b.id = ui.item_id
      WHERE ui.user_id = $1
      ORDER BY ui.created_at DESC`,
    [req.user.id]
  );
  res.json(rows);
});

module.exports = router;

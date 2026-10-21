const router = require('express').Router();
const pool = require('../db');
const { authenticate } = require('../auth');

const card = `u.id, u.public_id, u.display_name, u.avatar_url, u.level, u.role, u.bio`;

// Ubah profil sendiri.
router.put('/me', authenticate, async (req, res) => {
  const { display_name, bio, avatar_url, language } = req.body || {};
  const sets = [];
  const vals = [];
  const add = (col, v) => { vals.push(v); sets.push(`${col} = $${vals.length}`); };

  if (display_name !== undefined) {
    if (!String(display_name).trim()) return res.status(400).json({ error: 'Nama tidak boleh kosong' });
    add('display_name', String(display_name).trim().slice(0, 30));
  }
  if (bio !== undefined) add('bio', String(bio).slice(0, 200));
  if (language !== undefined) {
    if (!['id', 'en'].includes(language)) return res.status(400).json({ error: 'Bahasa tidak didukung' });
    add('language', language);
  }
  if (avatar_url !== undefined) {
    // Foto profil hanya boleh dari hasil unggahan ke server ini.
    if (avatar_url !== null && !/\/uploads\/[a-f0-9]+\.(png|jpg|gif|webp)$/.test(String(avatar_url))) {
      return res.status(400).json({ error: 'URL foto tidak valid' });
    }
    add('avatar_url', avatar_url);
  }
  if (!sets.length) return res.status(400).json({ error: 'Tidak ada perubahan' });
  vals.push(req.user.id);
  await pool.query(`UPDATE users SET ${sets.join(', ')} WHERE id = $${vals.length}`, vals);
  res.json({ ok: true });
});

// Hapus akun sendiri (wajib untuk Google Play). Data terkait ikut terhapus lewat ON DELETE CASCADE.
router.delete('/me', authenticate, async (req, res) => {
  if (req.user.role === 'developer') {
    return res.status(403).json({ error: 'Akun Developer tidak bisa dihapus dari aplikasi' });
  }
  await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);
  res.json({ ok: true });
});

// Daftar following / fans / visitors milik sendiri.
const lists = {
  following: `SELECT ${card} FROM follows f JOIN users u ON u.id = f.followee_id WHERE f.follower_id = $1 ORDER BY u.display_name`,
  fans: `SELECT ${card} FROM follows f JOIN users u ON u.id = f.follower_id WHERE f.followee_id = $1 ORDER BY u.display_name`,
  visitors: `SELECT ${card}, max(v.created_at) AS last_visit FROM visits v JOIN users u ON u.id = v.visitor_id
             WHERE v.user_id = $1 GROUP BY u.id ORDER BY last_visit DESC LIMIT 100`,
};
router.get('/me/people/:kind', authenticate, async (req, res) => {
  const q = lists[req.params.kind];
  if (!q) return res.status(404).json({ error: 'Tidak ditemukan' });
  const { rows } = await pool.query(q, [req.user.id]);
  res.json(rows);
});

// Profil pengguna lain. Membuka profil tercatat sebagai kunjungan (kecuali SVIP dengan perk hide_visit).
router.get('/users/:id', authenticate, async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { rows: [u] } = await pool.query(
    `SELECT ${card}, u.created_at,
            (SELECT count(*)::int FROM follows WHERE follower_id = u.id) AS following,
            (SELECT count(*)::int FROM follows WHERE followee_id = u.id) AS fans,
            EXISTS (SELECT 1 FROM follows WHERE follower_id = $2 AND followee_id = u.id) AS is_following
       FROM users u WHERE u.id = $1 AND NOT u.banned`,
    [id, req.user.id]
  );
  if (!u) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });

  if (id !== req.user.id) {
    const { rows: [hide] } = await pool.query(
      `SELECT (t.perks->>'hide_visit')::boolean AS hide FROM users me
         JOIN vip_tiers t ON t.id = me.vip_tier_id
        WHERE me.id = $1 AND me.vip_expires_at > now()`,
      [req.user.id]
    );
    if (!(hide && hide.hide)) {
      await pool.query('INSERT INTO visits (user_id, visitor_id) VALUES ($1, $2)', [id, req.user.id]);
    }
  }
  res.json(u);
});

router.post('/users/:id/follow', authenticate, async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (id === req.user.id) return res.status(400).json({ error: 'Tidak bisa mengikuti diri sendiri' });
  const { rowCount } = await pool.query('SELECT 1 FROM users WHERE id = $1 AND NOT banned', [id]);
  if (!rowCount) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  await pool.query('INSERT INTO follows (follower_id, followee_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.user.id, id]);
  res.json({ ok: true, is_following: true });
});

router.delete('/users/:id/follow', authenticate, async (req, res) => {
  await pool.query('DELETE FROM follows WHERE follower_id = $1 AND followee_id = $2', [req.user.id, parseInt(req.params.id, 10)]);
  res.json({ ok: true, is_following: false });
});

module.exports = router;

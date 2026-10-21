const router = require('express').Router();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { sign, publicUser } = require('../auth');

async function uniquePublicId() {
  for (let i = 0; i < 10; i++) {
    const id = 10000000 + Math.floor(Math.random() * 89999999);
    const { rowCount } = await pool.query('SELECT 1 FROM users WHERE public_id = $1', [id]);
    if (!rowCount) return id;
  }
  throw new Error('Gagal membuat ID unik');
}

// Login / daftar dengan Google. Aplikasi mengirim id_token; server memverifikasinya ke Google.
// GOOGLE_CLIENT_ID = Client ID tipe "Web" (boleh beberapa, dipisah koma).
router.post('/auth/google', async (req, res) => {
  const allowed = (process.env.GOOGLE_CLIENT_ID || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!allowed.length) return res.status(501).json({ error: 'Login Google belum dikonfigurasi di server' });

  const idToken = req.body && req.body.id_token;
  if (!idToken || typeof idToken !== 'string') return res.status(400).json({ error: 'Token Google tidak ada' });

  const r = await fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken));
  if (!r.ok) return res.status(401).json({ error: 'Token Google tidak valid' });
  const t = await r.json();

  const issuerOk = t.iss === 'accounts.google.com' || t.iss === 'https://accounts.google.com';
  if (!allowed.includes(t.aud) || !issuerOk || !t.sub) {
    return res.status(401).json({ error: 'Token Google tidak valid' });
  }
  if (String(t.email_verified) !== 'true') return res.status(401).json({ error: 'Email Google belum terverifikasi' });

  let { rows: [user] } = await pool.query('SELECT * FROM users WHERE google_sub = $1', [t.sub]);
  if (!user) {
    const name = String(t.name || String(t.email || 'Pengguna').split('@')[0]).slice(0, 30);
    const username = `g${crypto.randomBytes(5).toString('hex')}`;
    // Akun Google tidak punya password; hash acak membuat login username/password mustahil.
    const hash = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);
    ({ rows: [user] } = await pool.query(
      `INSERT INTO users (public_id, username, display_name, password_hash, google_sub, email, avatar_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [await uniquePublicId(), username, name, hash, t.sub, t.email || null, t.picture || null]
    ));
  }
  if (user.banned) return res.status(403).json({ error: 'Akun ini diblokir' });
  res.json({ token: sign(user), user: publicUser(user) });
});

module.exports = router;

const router = require('express').Router();
const pool = require('../db');
const { authenticate, requireRole } = require('../auth');

// Pengaturan yang bisa diatur Developer. Nilai awal dipakai bila belum pernah diubah.
const DEFAULTS = {
  checkin_rewards: [50, 60, 70, 80, 90, 100, 200], // koin per hari berturut-turut (siklus 7 hari)
  invite_reward: { inviter: 500, invitee: 200 },
  support: { whatsapp: '', email: '', hours: '09.00 - 21.00 WIB' },
};

const VALID = {
  checkin_rewards: (v) => Array.isArray(v) && v.length >= 1 && v.length <= 31 && v.every((n) => Number.isInteger(n) && n >= 0),
  invite_reward: (v) => v && Number.isInteger(v.inviter) && Number.isInteger(v.invitee) && v.inviter >= 0 && v.invitee >= 0,
  support: (v) => v && typeof v === 'object' && !Array.isArray(v),
};

async function getSetting(key) {
  const { rows } = await pool.query('SELECT value FROM app_settings WHERE key = $1', [key]);
  return rows[0] ? rows[0].value : DEFAULTS[key];
}

router.get('/settings', authenticate, async (_req, res) => {
  const out = {};
  for (const k of Object.keys(DEFAULTS)) out[k] = await getSetting(k);
  res.json(out);
});

router.put('/settings/:key', authenticate, requireRole('developer'), async (req, res) => {
  const { key } = req.params;
  if (!VALID[key]) return res.status(404).json({ error: 'Pengaturan tidak ditemukan' });
  const value = req.body && req.body.value;
  if (!VALID[key](value)) return res.status(400).json({ error: 'Nilai tidak valid' });
  await pool.query(
    `INSERT INTO app_settings (key, value) VALUES ($1, $2::jsonb)
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
    [key, JSON.stringify(value)]
  );
  res.json({ ok: true, value });
});

module.exports = router;
module.exports.getSetting = getSetting;

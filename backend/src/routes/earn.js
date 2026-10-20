const router = require('express').Router();
const pool = require('../db');
const { authenticate } = require('../auth');
const { getSetting } = require('./settings');

// "Hari ini" mengikuti zona waktu WIB agar reset harian terasa wajar bagi pengguna Indonesia.
const TODAY = "(now() AT TIME ZONE 'Asia/Jakarta')::date";

async function status(userId) {
  const rewards = await getSetting('checkin_rewards');
  const { rows: [last] } = await pool.query(
    `SELECT day, streak, (day = ${TODAY}) AS today, (day = ${TODAY} - 1) AS yesterday
       FROM checkins WHERE user_id = $1 ORDER BY day DESC LIMIT 1`,
    [userId]
  );
  const streak = last && (last.today || last.yesterday) ? last.streak : 0;
  return { rewards, streak, checked_in_today: !!(last && last.today) };
}

router.get('/earn/checkin', authenticate, async (req, res) => res.json(await status(req.user.id)));

router.post('/earn/checkin', authenticate, async (req, res) => {
  const rewards = await getSetting('checkin_rewards');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT 1 FROM users WHERE id = $1 FOR UPDATE', [req.user.id]); // cegah klaim ganda paralel
    const { rows: [last] } = await client.query(
      `SELECT streak, (day = ${TODAY}) AS today, (day = ${TODAY} - 1) AS yesterday
         FROM checkins WHERE user_id = $1 ORDER BY day DESC LIMIT 1`,
      [req.user.id]
    );
    if (last && last.today) throw Object.assign(new Error('Kamu sudah check-in hari ini'), { status: 409 });
    const streak = last && last.yesterday ? last.streak + 1 : 1;
    const reward = rewards[(streak - 1) % rewards.length];

    await client.query(`INSERT INTO checkins (user_id, day, streak, reward) VALUES ($1, ${TODAY}, $2, $3)`, [req.user.id, streak, reward]);
    const { rows: [u] } = await client.query('UPDATE users SET coins = coins + $1 WHERE id = $2 RETURNING coins', [reward, req.user.id]);
    await client.query('INSERT INTO coin_transactions (user_id, amount, reason) VALUES ($1, $2, $3)', [
      req.user.id, reward, `Check-in hari ke-${streak}`,
    ]);
    await client.query('COMMIT');
    res.json({ ok: true, reward, streak, coins: u.coins });
  } catch (e) {
    await client.query('ROLLBACK');
    if (e.status) return res.status(e.status).json({ error: e.message });
    throw e;
  } finally {
    client.release();
  }
});

// Info undangan: kode = ID publik pengguna.
router.get('/earn/invite', authenticate, async (req, res) => {
  const reward = await getSetting('invite_reward');
  const { rows: [r] } = await pool.query('SELECT count(*)::int AS n FROM users WHERE invited_by = $1', [req.user.id]);
  res.json({ code: String(req.user.public_id), invited: r.n, reward, total_earned: r.n * reward.inviter });
});

router.get('/me/coin-history', authenticate, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT amount, reason, created_at FROM coin_transactions WHERE user_id = $1 ORDER BY id DESC LIMIT 50',
    [req.user.id]
  );
  res.json(rows);
});

module.exports = router;

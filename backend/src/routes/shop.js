const router = require('express').Router();
const pool = require('../db');
const { authenticate } = require('../auth');

// Beli bingkai atau paket VIP/SVIP dengan koin.
router.post('/shop/buy', authenticate, async (req, res) => {
  const { type, id } = req.body || {};
  if (!['frame', 'vip'].includes(type)) return res.status(400).json({ error: 'Tipe tidak valid' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: [user] } = await client.query('SELECT * FROM users WHERE id = $1 FOR UPDATE', [req.user.id]);

    const table = type === 'frame' ? 'frames' : 'vip_tiers';
    const { rows: [item] } = await client.query(`SELECT * FROM ${table} WHERE id = $1 AND active = TRUE`, [id]);
    if (!item) throw Object.assign(new Error('Item tidak tersedia'), { status: 404 });

    const price = Number(type === 'frame' ? item.price : item.price_coins);
    if (Number(user.coins) < price) throw Object.assign(new Error('Koin tidak cukup'), { status: 402 });

    await client.query('UPDATE users SET coins = coins - $1 WHERE id = $2', [price, user.id]);
    await client.query(
      'INSERT INTO coin_transactions (user_id, amount, reason) VALUES ($1, $2, $3)',
      [user.id, -price, `Beli ${type}: ${item.name}`]
    );

    if (type === 'frame') {
      await client.query(
        `INSERT INTO user_items (user_id, item_type, item_id) VALUES ($1, 'frame', $2)
         ON CONFLICT DO NOTHING`,
        [user.id, item.id]
      );
    } else {
      await client.query(
        `UPDATE users SET vip_tier_id = $1,
           vip_expires_at = GREATEST(COALESCE(vip_expires_at, now()), now()) + ($2 || ' days')::interval
         WHERE id = $3`,
        [item.id, String(item.duration_days), user.id]
      );
    }

    await client.query('COMMIT');
    const { rows: [fresh] } = await pool.query('SELECT coins FROM users WHERE id = $1', [user.id]);
    res.json({ ok: true, coins: fresh.coins });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(e.status || 500).json({ error: e.status ? e.message : 'Terjadi kesalahan' });
  } finally {
    client.release();
  }
});

// Pasang / lepas bingkai yang dimiliki.
router.post('/me/frame', authenticate, async (req, res) => {
  const { frame_id } = req.body || {};
  if (frame_id) {
    const owns = await pool.query(
      "SELECT 1 FROM user_items WHERE user_id = $1 AND item_type = 'frame' AND item_id = $2",
      [req.user.id, frame_id]
    );
    if (!owns.rowCount) return res.status(403).json({ error: 'Kamu belum memiliki bingkai ini' });
  }
  await pool.query('UPDATE users SET frame_id = $1 WHERE id = $2', [frame_id || null, req.user.id]);
  res.json({ ok: true });
});

module.exports = router;

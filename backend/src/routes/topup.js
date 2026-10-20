const router = require('express').Router();
const crypto = require('crypto');
const pool = require('../db');
const { authenticate } = require('../auth');

const snapUrl = () =>
  process.env.MIDTRANS_IS_PRODUCTION === 'true'
    ? 'https://app.midtrans.com/snap/v1/transactions'
    : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

// Buat transaksi Midtrans Snap untuk paket koin. Mengembalikan redirect_url untuk dibuka di browser.
router.post('/topup/create', authenticate, async (req, res) => {
  const serverKey = process.env.MIDTRANS_SERVER_KEY;
  if (!serverKey) return res.status(501).json({ error: 'Pembayaran belum dikonfigurasi di server' });

  const { rows: [pkg] } = await pool.query('SELECT * FROM coin_packages WHERE id = $1 AND active = TRUE', [
    req.body && req.body.package_id,
  ]);
  if (!pkg) return res.status(404).json({ error: 'Paket tidak tersedia' });
  if (Number(pkg.price_idr) <= 0) return res.status(400).json({ error: 'Harga paket belum diatur' });

  const orderId = `ZP-${req.user.id}-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
  await pool.query(
    'INSERT INTO topups (order_id, user_id, package_id, coins, amount_idr) VALUES ($1, $2, $3, $4, $5)',
    [orderId, req.user.id, pkg.id, pkg.coins, pkg.price_idr]
  );

  const r = await fetch(snapUrl(), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: 'Basic ' + Buffer.from(serverKey + ':').toString('base64'),
    },
    body: JSON.stringify({
      transaction_details: { order_id: orderId, gross_amount: Number(pkg.price_idr) },
      item_details: [{ id: String(pkg.id), price: Number(pkg.price_idr), quantity: 1, name: `${pkg.name} (${pkg.coins} koin)`.slice(0, 50) }],
      customer_details: { first_name: req.user.display_name.slice(0, 40) },
    }),
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok || !data.redirect_url) {
    await pool.query("UPDATE topups SET status = 'failed' WHERE order_id = $1", [orderId]);
    console.error('Midtrans error', r.status, data);
    return res.status(502).json({ error: 'Gagal membuat pembayaran, coba lagi' });
  }
  res.json({ order_id: orderId, redirect_url: data.redirect_url });
});

// Webhook dari Midtrans. Tidak memakai login: keaslian diperiksa lewat signature_key.
router.post('/topup/notify', async (req, res) => {
  const serverKey = process.env.MIDTRANS_SERVER_KEY;
  const n = req.body || {};
  if (!serverKey || !n.order_id) return res.status(400).json({ error: 'Bad request' });

  const expected = crypto
    .createHash('sha512')
    .update(`${n.order_id}${n.status_code}${n.gross_amount}${serverKey}`)
    .digest('hex');
  const given = Buffer.from(String(n.signature_key || ''));
  const want = Buffer.from(expected);
  if (given.length !== want.length || !crypto.timingSafeEqual(given, want)) {
    return res.status(403).json({ error: 'Signature tidak valid' });
  }

  const paid = n.transaction_status === 'settlement' || (n.transaction_status === 'capture' && n.fraud_status === 'accept');
  const failed = ['expire', 'cancel', 'deny', 'failure'].includes(n.transaction_status);

  if (failed) {
    await pool.query("UPDATE topups SET status = 'failed' WHERE order_id = $1 AND status = 'pending'", [n.order_id]);
    return res.json({ ok: true });
  }
  if (!paid) return res.json({ ok: true }); // masih pending

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Hanya satu notifikasi yang berhasil mengubah status ke 'paid' sehingga koin tidak ganda.
    const { rows: [t] } = await client.query(
      `UPDATE topups SET status = 'paid', paid_at = now()
        WHERE order_id = $1 AND status <> 'paid' AND amount_idr = $2 RETURNING *`,
      [n.order_id, Math.round(Number(n.gross_amount))]
    );
    if (t) {
      const { rows: [u] } = await client.query('UPDATE users SET coins = coins + $1 WHERE id = $2 RETURNING coins', [t.coins, t.user_id]);
      await client.query('INSERT INTO coin_transactions (user_id, amount, reason) VALUES ($1, $2, $3)', [
        t.user_id,
        t.coins,
        `Top-up ${n.order_id}`,
      ]);
      await client.query('COMMIT');
      const io = req.app.get('io');
      if (io) io.to(`user:${t.user_id}`).emit('wallet:update', { coins: u.coins });
    } else {
      await client.query('ROLLBACK');
    }
    res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    res.status(500).json({ error: 'Gagal memproses' }); // Midtrans akan mengirim ulang
  } finally {
    client.release();
  }
});

router.get('/topup/history', authenticate, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT order_id, coins, amount_idr, status, created_at FROM topups WHERE user_id = $1 ORDER BY id DESC LIMIT 30',
    [req.user.id]
  );
  res.json(rows);
});

module.exports = router;

require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('./db');

(async () => {
  const username = (process.env.DEV_USERNAME || 'developer').toLowerCase();
  const password = process.env.DEV_PASSWORD;
  if (!password || password.length < 8) {
    throw new Error('Isi DEV_PASSWORD (min. 8 karakter) di file .env sebelum seed');
  }

  // Akun Developer pertama.
  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO users (public_id, username, display_name, password_hash, role, coins)
     VALUES ($1, $2, 'Developer', $3, 'developer', 1000000)
     ON CONFLICT (username) DO UPDATE SET role = 'developer', password_hash = EXCLUDED.password_hash`,
    [10000001, username, hash]
  );

  // Contoh isi awal. Semuanya bisa diubah Developer dari dalam aplikasi.
  const count = async (t) => (await pool.query(`SELECT count(*)::int AS n FROM ${t}`)).rows[0].n;

  if (!(await count('vip_tiers'))) {
    await pool.query(
      `INSERT INTO vip_tiers (name, kind, price_coins, duration_days, perks) VALUES
       ('VIP', 'VIP', 20000, 30, '{"entry_effect": true}'),
       ('SVIP', 'SVIP', 100000, 30, '{"entry_effect": true, "kick_protection": true, "hide_visit": true}')`
    );
  }
  if (!(await count('gifts'))) {
    await pool.query(
      `INSERT INTO gifts (name, price) VALUES ('Mawar', 10), ('Hati', 50), ('Mahkota', 500), ('Roket', 2000)`
    );
  }
  if (!(await count('coin_packages'))) {
    await pool.query(
      `INSERT INTO coin_packages (name, coins, price_idr) VALUES
       ('Paket Kecil', 1000, 15000), ('Paket Sedang', 6000, 79000), ('Paket Besar', 30000, 389000)`
    );
  }
  if (!(await count('frames'))) {
    await pool.query(`INSERT INTO frames (name, price) VALUES ('Bingkai Emas', 3000), ('Bingkai Neon', 5000)`);
  }
  if (!(await count('badges'))) {
    await pool.query(
      `INSERT INTO badges (name, description) VALUES ('Pengguna Baru', 'Lencana selamat datang')`
    );
  }

  console.log(`Seed selesai. Login Developer: ${username}`);
  await pool.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});

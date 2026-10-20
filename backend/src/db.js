const { Pool, types } = require('pg');

// BIGINT (koin, harga) dikembalikan sebagai angka, bukan string.
types.setTypeParser(20, (v) => parseInt(v, 10));

module.exports = new Pool({ connectionString: process.env.DATABASE_URL });

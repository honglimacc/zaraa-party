const jwt = require('jsonwebtoken');
const pool = require('./db');

// Urutan hak akses: makin tinggi makin besar.
const RANK = { user: 1, admin: 2, super_admin: 3, developer: 4 };

const sign = (user) =>
  jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });

async function userFromToken(token) {
  if (!token) return null;
  try {
    const { id } = jwt.verify(token, process.env.JWT_SECRET);
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
    const user = rows[0];
    if (!user || user.banned) return null;
    return user;
  } catch (_) {
    return null;
  }
}

async function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const user = await userFromToken(header.replace(/^Bearer\s+/i, ''));
  if (!user) return res.status(401).json({ error: 'Silakan login kembali' });
  req.user = user;
  next();
}

const requireRole = (minRole) => (req, res, next) =>
  RANK[req.user.role] >= RANK[minRole]
    ? next()
    : res.status(403).json({ error: 'Akses ditolak' });

const publicUser = (u) => {
  const { password_hash, ...rest } = u;
  return rest;
};

module.exports = { RANK, sign, userFromToken, authenticate, requireRole, publicUser };

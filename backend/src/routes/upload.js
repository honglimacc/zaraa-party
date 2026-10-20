const router = require('express').Router();
const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { authenticate, RANK } = require('../auth');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// Jenis file ditentukan dari isi file (magic bytes), bukan dari nama atau header kiriman klien.
function detect(buf) {
  if (buf.length < 12) return null;
  if (buf.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return { ext: 'png', kind: 'image' };
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { ext: 'jpg', kind: 'image' };
  if (buf.slice(0, 4).toString() === 'GIF8') return { ext: 'gif', kind: 'image' };
  if (buf.slice(0, 4).toString() === 'RIFF' && buf.slice(8, 12).toString() === 'WEBP') return { ext: 'webp', kind: 'image' };
  // Animasi Lottie = JSON dengan "layers".
  try {
    const j = JSON.parse(buf.toString('utf8'));
    if (j && Array.isArray(j.layers)) return { ext: 'json', kind: 'animation' };
  } catch (_) { /* bukan JSON */ }
  return null;
}

// Klien mengirim byte mentah dengan Content-Type: application/octet-stream.
router.post(
  '/upload',
  authenticate,
  express.raw({ type: 'application/octet-stream', limit: '8mb' }),
  (req, res) => {
    const buf = req.body;
    if (!Buffer.isBuffer(buf) || !buf.length) return res.status(400).json({ error: 'File kosong' });

    const isDev = req.user.role === 'developer';
    const info = detect(buf);
    if (!info) return res.status(400).json({ error: 'Format tidak didukung (PNG, JPG, GIF, WEBP, atau Lottie JSON)' });
    // Pengguna biasa hanya boleh mengunggah gambar kecil (untuk foto profil).
    if (!isDev) {
      if (info.kind !== 'image') return res.status(403).json({ error: 'Hanya Developer yang boleh mengunggah animasi' });
      if (buf.length > 2 * 1024 * 1024) return res.status(413).json({ error: 'Ukuran maksimal 2 MB' });
    }

    const name = `${crypto.randomBytes(12).toString('hex')}.${info.ext}`;
    fs.writeFileSync(path.join(UPLOAD_DIR, name), buf);
    const base = process.env.PUBLIC_URL || `${req.protocol}://${req.get('host')}`;
    res.status(201).json({ url: `${base}/uploads/${name}`, kind: info.kind, size: buf.length });
  }
);

module.exports = router;
module.exports.UPLOAD_DIR = UPLOAD_DIR;

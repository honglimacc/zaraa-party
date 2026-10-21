const router = require('express').Router();

// Halaman publik yang diwajibkan Google Play: kebijakan privasi & cara menghapus akun.
const page = (title, body) => `<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} - Zaraa Party</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:720px;margin:0 auto;padding:24px;color:#1b1b1f}
h1{color:#00a37a}a{color:#00a37a}</style></head><body>${body}</body></html>`;

const contact = () => process.env.CONTACT_EMAIL || 'admin@example.com';

router.get('/privacy', (_req, res) => {
  res.type('html').send(page('Kebijakan Privasi', `
<h1>Kebijakan Privasi Zaraa Party</h1>
<p>Terakhir diperbarui: 21 Oktober 2026.</p>
<h2>Data yang kami kumpulkan</h2>
<ul>
<li><b>Akun:</b> username, nama tampilan, foto profil, bio, dan kata sandi (disimpan terenkripsi). Jika masuk dengan Google, kami menerima nama, alamat email, dan foto profil Google kamu.</li>
<li><b>Aktivitas:</b> room yang dibuat, pesan di room dan pesan pribadi, gift, pembelian, riwayat koin, check-in, pengikut/pengunjung profil, dan tiket bantuan.</li>
<li><b>Suara:</b> audio dari mikrofon dikirim langsung ke peserta room saat kamu duduk di kursi mic. Kami tidak merekam audio.</li>
<li><b>Pembayaran:</b> top-up diproses oleh Midtrans. Kami tidak menyimpan data kartu; kami hanya menyimpan nomor pesanan, jumlah, dan status.</li>
</ul>
<h2>Cara data dipakai</h2>
<p>Untuk menjalankan aplikasi (login, room suara, pesan, toko), mencegah penyalahgunaan, dan membantu pengguna lewat Customer Service. Kami tidak menjual data pribadi.</p>
<h2>Berbagi data</h2>
<p>Data dibagikan hanya kepada penyedia layanan yang diperlukan: Google (login), Midtrans (pembayaran), LiveKit (transmisi suara), dan penyedia hosting server.</p>
<h2>Penyimpanan dan penghapusan</h2>
<p>Data disimpan selama akun aktif. Kamu dapat menghapus akun kapan saja di aplikasi (Profil &rarr; Hapus Akun) atau lewat <a href="/hapus-akun">halaman penghapusan akun</a>. Penghapusan menghilangkan profil, pesan, item, dan riwayat transaksi akun tersebut.</p>
<h2>Anak-anak</h2>
<p>Aplikasi ini tidak ditujukan bagi anak di bawah 13 tahun.</p>
<h2>Kontak</h2>
<p>Pertanyaan tentang privasi: <a href="mailto:${contact()}">${contact()}</a></p>`));
});

router.get('/hapus-akun', (_req, res) => {
  res.type('html').send(page('Hapus Akun', `
<h1>Hapus Akun Zaraa Party</h1>
<h2>Lewat aplikasi</h2>
<ol><li>Buka tab <b>Saya</b> (Profil).</li><li>Gulir ke bawah, pilih <b>Hapus Akun</b>.</li><li>Konfirmasi. Akun dan datanya langsung dihapus permanen.</li></ol>
<h2>Tidak bisa membuka aplikasi?</h2>
<p>Kirim email ke <a href="mailto:${contact()}">${contact()}</a> dari alamat yang terdaftar di akunmu, sertakan ID akun (angka di bawah namamu). Kami memproses permintaan dalam 7 hari.</p>
<h2>Data yang dihapus</h2>
<p>Profil, foto, pesan pribadi, item, koin, dan riwayat transaksi akun. Tindakan ini tidak bisa dibatalkan.</p>`));
});

module.exports = router;

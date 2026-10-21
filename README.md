# Zaraa Party

Aplikasi **Voice Room real-time**. Mobile: Flutter. Server: Node.js + PostgreSQL + Socket.IO. Suara: LiveKit.

## Peran

| Peran | Bisa apa |
|---|---|
| User | Masuk room, duduk di kursi mic, chat, kirim gift, beli bingkai/VIP, atur My Items |
| Admin | Semua User + blokir pengguna, bisukan mic, keluarkan pengguna dari room, tutup room |
| Super Admin | Semua Admin + ubah peran Admin/User, tambah/kurangi koin, beri item |
| Developer | Semua Super Admin + atur **seluruh isi aplikasi**: banner, gift, bingkai, lencana, VIP/SVIP, paket koin; boleh mengatur semua peran |

Aturan hierarki: staff hanya bisa memblokir pengguna yang perannya lebih rendah. Selain Developer, tidak ada yang bisa menaikkan peran sampai setara atau melebihi dirinya.

## Struktur

```
backend/   API Express + Socket.IO + skema PostgreSQL
app/       Aplikasi Flutter (lib/screens: profil, store, room, admin, developer)
docker-compose.yml   PostgreSQL untuk pengembangan
```

## Menjalankan backend

```bash
docker compose up -d                 # PostgreSQL
cd backend
cp .env.example .env                 # isi JWT_SECRET & DEV_PASSWORD
npm install
npm run migrate                      # buat tabel
npm run seed                         # buat akun Developer + contoh isi awal
npm run dev                          # http://localhost:3000
```

Login Developer pertama: `DEV_USERNAME` / `DEV_PASSWORD` dari `.env`.

## Menjalankan aplikasi

Folder `android/` dan `ios/` dibuat oleh Flutter, jadi jalankan sekali:

```bash
cd app
flutter create . --org com.zaraa --project-name zaraa_party
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000   # 10.0.2.2 = localhost dari emulator Android
```

Untuk suara (LiveKit), tambahkan izin berikut di `android/app/src/main/AndroidManifest.xml`:
`RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `INTERNET`, `BLUETOOTH`, `BLUETOOTH_CONNECT`;
dan `NSMicrophoneUsageDescription` di `ios/Runner/Info.plist`.
Buat proyek di <https://livekit.io> (ada paket gratis) lalu isi `LIVEKIT_*` di `.env`.
Tanpa LiveKit, kursi, chat, dan gift tetap jalan; hanya audio yang belum aktif.

## Fitur tahap 2

| Fitur | Cara kerja |
|---|---|
| Upload gambar & animasi | `POST /api/upload` (byte mentah). Jenis file dicek dari isi file, bukan nama. User biasa: gambar ≤ 2 MB (foto profil). Developer: gambar + animasi Lottie `.json` ≤ 8 MB. SVG sengaja ditolak. File disimpan di `backend/uploads/` dan dilayani di `/uploads/...`. Di Developer Panel, kolom URL punya tombol unggah. |
| Top-up koin | Midtrans Snap. `POST /api/topup/create` -> buka `redirect_url`. Koin masuk otomatis lewat webhook `POST /api/topup/notify` (signature diverifikasi, koin tidak bisa ganda). |
| Pesan pribadi | Riwayat lewat REST (`/api/dm/...`), pesan masuk real-time lewat Socket.IO (`dm:new`), badge belum dibaca di tab Pesan. |
| Follow / Fans / Visitors | Buka profil orang lain, ikuti, lihat daftar Following/Fans/Visitors. SVIP dengan perk `hide_visit` tidak tercatat sebagai pengunjung. |
| Invite Friends | Kode undangan = ID publik. Dimasukkan saat daftar; hadiah koin untuk kedua pihak. |
| Earn Cash | Check-in harian berantai (reset hari mengikuti WIB) + riwayat koin. |
| CP Space | Ajukan CP lewat ID, terima/tolak, putuskan. Satu orang hanya bisa punya satu CP. |
| Customer Service | Kontak WhatsApp/email dari pengaturan + tiket; Admin ke atas membalas dari Admin Panel. |
| Language | Indonesia / Inggris, disimpan di akun. Baru mencakup menu, label utama, dan layar Home/Profil; teks lain masih Indonesia. |
| Efek gift | Lottie (`.json`), gambar animasi (gif/webp), atau efek bawaan bila tidak ada animasi. Gift diputar berurutan. |

Developer Panel punya tab **Pengaturan** untuk mengubah hadiah check-in, hadiah undangan, dan kontak CS tanpa deploy ulang.

### Menyiapkan pembayaran (Midtrans)

1. Daftar di <https://dashboard.midtrans.com>, ambil **Server Key** (mulai dari sandbox).
2. Isi `MIDTRANS_SERVER_KEY` di `backend/.env`.
3. Di dashboard: Settings -> Configuration -> **Payment Notification URL** = `https://DOMAINMU/api/topup/notify`. Server harus bisa diakses dari internet (HTTPS).
4. Isi `price_idr` paket koin lewat Developer Panel (tab Paket Koin). Untuk produksi set `MIDTRANS_IS_PRODUCTION=true` dan pakai Server Key produksi.

Set `PUBLIC_URL` ke alamat publik server agar URL gambar yang diunggah benar. Folder `uploads/` perlu disimpan permanen (volume) saat deploy.

Android: tambahkan `<queries>` untuk `https`, `mailto` di `AndroidManifest.xml` agar `url_launcher` bisa membuka WhatsApp/email/pembayaran (lihat dokumentasi url_launcher).

## Login Google, publikasi, dan alamat server

- **Alamat server & Client ID Google** ditulis di `app/app_config.json` (keduanya bukan rahasia). Setelah terisi, APK dibangun ulang otomatis dan pengguna tidak perlu mengatur apa pun; tombol "Atur alamat server" hilang dan tombol "Lanjutkan dengan Google" muncul.
- **Tanda tangan aplikasi:** keystore tetap ada terenkripsi di `.github/zaraa.keystore.enc`; kata sandinya disimpan di GitHub Secret `KEYSTORE_PASSPHRASE`. Jangan hilangkan, karena Google Sign-In dan Play Store mengenali aplikasi dari kunci ini.
- **Setiap build** menerbitkan `ZaraaParty.apk` (pasang langsung) dan `ZaraaParty.aab` (unggah ke Google Play) di Releases -> "terbaru".
- **Halaman wajib Play Store:** `https://SERVERMU/privacy` dan `https://SERVERMU/hapus-akun`. Hapus akun juga ada di aplikasi (Profil -> Hapus Akun). Teks kebijakan privasi adalah draf umum; sesuaikan bila perlu.

## Belum ada

Pembayaran selain Midtrans, pesan gambar/suara di DM, notifikasi push saat aplikasi tertutup, terjemahan penuh seluruh teks, gift yang menambah koin untuk penerima, moderasi konten unggahan.

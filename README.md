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

## Status fitur

Sudah ada: login/daftar, profil sesuai desain acuan, Home + banner + daftar room, room real-time (8 kursi, chat, gift, mute, kick), Store (bingkai, VIP/SVIP), My Items, Admin Panel, Developer Panel (CRUD semua konten).

Belum ada (tahap berikutnya): upload gambar/animasi (saat ini lewat URL), top-up koin lewat pembayaran, pesan pribadi, follow/fans, Invite Friends, Earn Cash, CP Space, Customer Service, pilihan bahasa, efek animasi gift.

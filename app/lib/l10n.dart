/// Terjemahan sederhana Indonesia / Inggris. Bahasa disimpan di akun pengguna (kolom users.language).
/// Untuk menambah teks: tambahkan kunci di kedua peta. Teks yang belum diterjemahkan jatuh ke Indonesia.
class L {
  static String lang = 'id';

  static const _id = <String, String>{
    'home': 'Beranda',
    'messages': 'Pesan',
    'invite': 'Undang Teman',
    'earn': 'Dapatkan Koin',
    'cp': 'Ruang CP',
    'my_items': 'Item Saya',
    'store': 'Toko',
    'support': 'Layanan Pelanggan',
    'language': 'Bahasa',
    'admin': 'Panel Admin',
    'developer': 'Panel Developer',
    'logout': 'Keluar',
    'following': 'Mengikuti',
    'fans': 'Penggemar',
    'visitors': 'Pengunjung',
    'wallet': 'Dompet',
    'level': 'Level',
    'badges': 'Lencana',
    'activate_svip': 'Aktifkan SVIP',
    'follow': 'Ikuti',
    'unfollow': 'Berhenti mengikuti',
    'message': 'Kirim pesan',
    'save': 'Simpan',
    'cancel': 'Batal',
    'send': 'Kirim',
    'active_rooms': 'Room Aktif',
    'create_room': 'Buat Room',
  };

  static const _en = <String, String>{
    'home': 'Home',
    'messages': 'Messages',
    'invite': 'Invite Friends',
    'earn': 'Earn Coins',
    'cp': 'CP Space',
    'my_items': 'My Items',
    'store': 'Store',
    'support': 'Customer Service',
    'language': 'Language',
    'admin': 'Admin Panel',
    'developer': 'Developer Panel',
    'logout': 'Logout',
    'following': 'Following',
    'fans': 'Fans',
    'visitors': 'Visitors',
    'wallet': 'Wallet',
    'level': 'Level',
    'badges': 'Badges',
    'activate_svip': 'Activate SVIP',
    'follow': 'Follow',
    'unfollow': 'Unfollow',
    'message': 'Message',
    'save': 'Save',
    'cancel': 'Cancel',
    'send': 'Send',
    'active_rooms': 'Active Rooms',
    'create_room': 'Create Room',
  };

  static String t(String key) => (lang == 'en' ? _en[key] : _id[key]) ?? _id[key] ?? key;
  static String get langName => lang == 'en' ? 'English' : 'Indonesia';
}

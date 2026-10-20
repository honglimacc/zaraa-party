import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import 'api.dart';

/// Koneksi Socket.IO global untuk kanal pribadi pengguna: pesan masuk, saldo, notifikasi.
/// (Room punya koneksi sendiri di room_screen.dart.)
class Rt {
  static final Rt i = Rt._();
  Rt._();

  sio.Socket? _s;
  String? _token;

  /// Jumlah pesan pribadi belum dibaca (untuk badge tab Pesan).
  final unread = ValueNotifier<int>(0);

  /// Pesan pribadi baru dari server.
  final dmStream = StreamController<Map>.broadcast();

  /// Saldo koin terbaru (top-up berhasil, dll).
  final walletStream = StreamController<dynamic>.broadcast();

  void connect(String? token) {
    if (token == null || token == _token) return;
    disconnect();
    _token = token;
    final s = sio.io(
      Api.baseUrl,
      sio.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).enableReconnection().build(),
    );
    s.on('dm:new', (d) {
      unread.value++;
      dmStream.add(Map.from(d));
    });
    s.on('wallet:update', (d) => walletStream.add(d['coins']));
    s.onConnect((_) => refreshUnread());
    _s = s;
  }

  Future<void> refreshUnread() async {
    try {
      final r = await Api.i.get('/dm/unread-count');
      unread.value = r['unread'] as int;
    } catch (_) {}
  }

  void disconnect() {
    _s?.dispose();
    _s = null;
    _token = null;
    unread.value = 0;
  }
}

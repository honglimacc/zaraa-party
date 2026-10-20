import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../api.dart';
import '../auth_state.dart';
import '../theme.dart';
import '../widgets/gift_effect.dart';

/// Room suara real-time: 8 kursi mic, chat, dan kirim gift.
/// Status kursi/chat/gift lewat Socket.IO, audio lewat LiveKit.
class RoomScreen extends StatefulWidget {
  final Map room;
  const RoomScreen({super.key, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final sio.Socket socket;
  lk.Room? voice;
  List seats = List.filled(8, null);
  int online = 0;
  final List<Map> chat = [];
  final input = TextEditingController();
  final scroll = ScrollController();
  Map? giftBanner;
  final List<Map> giftQueue = []; // gift diputar berurutan agar efek tidak saling menimpa
  int giftSeq = 0;

  int get myId => context.read<AuthState>().me!['id'] as int;
  int? get mySeat {
    for (var i = 0; i < seats.length; i++) {
      if (seats[i] != null && seats[i]['userId'] == myId) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthState>().token;
    socket = sio.io(
      Api.baseUrl,
      sio.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build(),
    );
    socket.onConnect((_) => socket.emit('room:join', widget.room['id']));
    socket.on('room:state', (d) {
      if (!mounted) return;
      setState(() {
        seats = List.from(d['seats']);
        online = d['online'] ?? 0;
      });
      _syncMic();
    });
    socket.on('chat:message', (d) => _addChat(Map.from(d)));
    socket.on('chat:system', (d) => _addChat({'system': true, 'text': d['text']}));
    socket.on('gift:sent', (d) {
      if (!mounted) return;
      final g = Map.from(d);
      _addChat({'system': true, 'text': '${g['from']['name']} mengirim ${g['gift']['name']} x${g['qty']}'});
      giftQueue.add(g);
      if (giftBanner == null) _playNextGift();
    });
    socket.on('wallet:update', (d) => context.read<AuthState>().setCoins(d['coins']));
    socket.on('error:msg', (m) => mounted ? toast(context, '$m') : null);
    socket.on('room:kicked', (_) {
      if (mounted) {
        toast(context, 'Kamu dikeluarkan dari room');
        Navigator.pop(context);
      }
    });
    socket.connect();
    _connectVoice();
  }

  void _playNextGift() {
    if (!mounted || giftQueue.isEmpty) return;
    setState(() {
      giftBanner = giftQueue.removeAt(0);
      giftSeq++;
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      setState(() => giftBanner = null);
      _playNextGift();
    });
  }

  Future<void> _connectVoice() async {
    try {
      final r = await Api.i.post('/rooms/${widget.room['id']}/voice-token');
      final room = lk.Room();
      await room.connect(r['url'], r['token']);
      voice = room;
      _syncMic();
    } catch (e) {
      // Suara opsional: chat dan kursi tetap berfungsi bila LiveKit belum dikonfigurasi.
      if (mounted) toast(context, 'Suara belum aktif: $e');
    }
  }

  // Mikrofon hanya menyala saat duduk di kursi dan tidak dibisukan.
  void _syncMic() {
    final s = mySeat;
    final on = s != null && seats[s]['muted'] != true;
    voice?.localParticipant?.setMicrophoneEnabled(on).catchError((_) => null);
  }

  void _addChat(Map m) {
    if (!mounted) return;
    setState(() => chat.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    socket.emit('room:leave');
    socket.dispose();
    voice?.disconnect();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = input.text.trim();
    if (t.isEmpty) return;
    socket.emit('chat:send', {'text': t});
    input.clear();
  }

  void _tapSeat(int i) {
    final s = seats[i];
    final auth = context.read<AuthState>();
    if (s == null) return socket.emit('mic:take', {'seat': i});
    final mine = s['userId'] == myId;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
          if (mine || auth.isStaff)
            ListTile(
              leading: Icon(s['muted'] == true ? Icons.mic_rounded : Icons.mic_off_rounded),
              title: Text(s['muted'] == true ? 'Nyalakan mic' : 'Bisukan'),
              onTap: () {
                Navigator.pop(context);
                socket.emit('mic:mute', {'seat': i, 'muted': s['muted'] != true});
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Turun dari kursi'),
              onTap: () {
                Navigator.pop(context);
                socket.emit('mic:leave');
              },
            ),
          if (!mine)
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: const Text('Kirim gift'),
              onTap: () {
                Navigator.pop(context);
                _giftSheet(s['userId']);
              },
            ),
          if (!mine && auth.isStaff)
            ListTile(
              leading: const Icon(Icons.gavel_rounded, color: Colors.red),
              title: const Text('Keluarkan dari room'),
              onTap: () {
                Navigator.pop(context);
                socket.emit('room:kick', {'userId': s['userId']});
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _giftSheet(int? toUserId) async {
    List gifts;
    try {
      gifts = await Api.i.get('/catalog/gifts') as List;
    } catch (e) {
      return toast(context, '$e');
    }
    if (!mounted) return;
    int? target = toUserId ?? widget.room['owner_id'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kirim Gift  •  Koin kamu: ${Z.num(context.read<AuthState>().me!['coins'])}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (gifts.isEmpty) const Text('Belum ada gift.', style: TextStyle(color: Z.muted)),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final g in gifts)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(context);
                      socket.emit('gift:send', {'giftId': g['id'], 'toUserId': target, 'qty': 1});
                    },
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(14)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        (g['icon_url'] ?? '').toString().isNotEmpty
                            ? Image.network(g['icon_url'], width: 36, height: 36, errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard_rounded))
                            : const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF2657A), size: 32),
                        const SizedBox(height: 4),
                        Text(g['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        Text(Z.num(g['price']), style: const TextStyle(fontSize: 12, color: Z.gold, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthState>();
    return Scaffold(
      backgroundColor: const Color(0xFF1E2235),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        foregroundColor: Colors.white,
        title: Text(widget.room['title'] ?? 'Room', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('$online online', style: const TextStyle(color: Colors.white70)))),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              children: [for (var i = 0; i < seats.length; i++) _seat(i)],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: chat.length,
              itemBuilder: (_, i) {
                final m = chat[i];
                final sys = m['system'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: sys
                      ? Text(m['text'], style: const TextStyle(color: Color(0xFF7CF0C9), fontSize: 13))
                      : Text.rich(TextSpan(children: [
                          TextSpan(text: '${m['name']}: ', style: const TextStyle(color: Color(0xFFFFD27A), fontWeight: FontWeight.w700)),
                          TextSpan(text: m['text'], style: const TextStyle(color: Colors.white)),
                        ])),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: Z.mint)),
                IconButton(onPressed: () => _giftSheet(null), icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFB866))),
              ]),
            ),
          ),
        ]),
        if (giftBanner != null)
          Positioned.fill(child: GiftEffect(key: ValueKey(giftSeq), gift: giftBanner!['gift'], qty: giftBanner!['qty'])),
        if (giftBanner != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD27A), Color(0xFFFF8FA3)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text('🎁 ${giftBanner!['from']['name']} mengirim ${giftBanner!['gift']['name']} x${giftBanner!['qty']}',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  Widget _seat(int i) {
    final s = seats[i];
    return GestureDetector(
      onTap: () => _tapSeat(i),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: s == null ? Colors.white12 : const Color(0xFFE3F9F1),
            backgroundImage: s != null && (s['avatar'] ?? '').toString().isNotEmpty ? NetworkImage(s['avatar']) : null,
            child: s == null
                ? const Icon(Icons.add_rounded, color: Colors.white38)
                : ((s['avatar'] ?? '').toString().isEmpty ? const Icon(Icons.person_rounded, color: Z.mint) : null),
          ),
          if (s != null && s['muted'] == true)
            const Positioned(right: -2, bottom: -2, child: CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.mic_off_rounded, size: 12, color: Colors.white))),
        ]),
        const SizedBox(height: 4),
        Text(s == null ? '${i + 1}' : (s['name'] ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

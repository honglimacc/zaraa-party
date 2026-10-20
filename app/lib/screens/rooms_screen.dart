import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'room_screen.dart';

/// Tab Home: banner (diatur Developer) + daftar room yang sedang aktif.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List rooms = [];
  List banners = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.i.get('/rooms'), Api.i.get('/catalog/banners')]);
      if (!mounted) return;
      setState(() {
        rooms = r[0] as List;
        banners = r[1] as List;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  Future<void> _create() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buat Room'),
        content: TextField(controller: c, maxLength: 60, decoration: const InputDecoration(hintText: 'Judul room')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Buat')),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      final room = await Api.i.post('/rooms', {'title': title});
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(room: Map.from(room))));
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: Z.mint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.mic_rounded),
        label: const Text('Buat Room'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Text('Zaraa Party', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Z.text)),
              const SizedBox(height: 14),
              if (banners.isNotEmpty) _bannerStrip(),
              const SizedBox(height: 16),
              const Text('Room Aktif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Z.mint))),
              if (error != null) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(error!, style: const TextStyle(color: Z.muted)))),
              if (!loading && error == null && rooms.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Belum ada room. Buat yang pertama!', style: TextStyle(color: Z.muted)))),
              for (final r in rooms) _roomTile(r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerStrip() => SizedBox(
        height: 130,
        child: PageView(
          children: [
            for (final b in banners)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF7CF0C9), Color(0xFF6EC1FF)]),
                  image: (b['image_url'] ?? '').toString().isNotEmpty
                      ? DecorationImage(image: NetworkImage(b['image_url']), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(14),
                child: Text(b['title'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)])),
              ),
          ],
        ),
      );

  Widget _roomTile(Map r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE3F9F1),
            backgroundImage: (r['cover_url'] ?? '').toString().isNotEmpty ? NetworkImage(r['cover_url']) : null,
            child: const Icon(Icons.graphic_eq_rounded, color: Z.mint),
          ),
          title: Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Host: ${r['owner_name']}'),
          trailing: const Icon(Icons.chevron_right_rounded, color: Z.muted),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(room: Map.from(r))));
            _load();
          },
        ),
      );
}

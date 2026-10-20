import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

/// Bingkai dan lencana milik pengguna. Bingkai bisa dipasang / dilepas.
class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  List items = [];
  int? equippedFrame;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.i.get('/me/items'), Api.i.get('/me')]);
      if (mounted) setState(() {
        items = r[0] as List;
        equippedFrame = (r[1] as Map)['frame_id'] as int?;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _toggleFrame(Map it) async {
    final wear = equippedFrame != it['item_id'];
    try {
      await Api.i.post('/me/frame', {'frame_id': wear ? it['item_id'] : null});
      setState(() => equippedFrame = wear ? it['item_id'] : null);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Items')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : items.isEmpty
              ? const Center(child: Text('Belum punya item. Cek Store!', style: TextStyle(color: Z.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final it in items)
                      Card(
                        elevation: 0,
                        color: const Color(0xFFF6F7F9),
                        child: ListTile(
                          leading: (it['image_url'] ?? '').toString().isNotEmpty
                              ? Image.network(it['image_url'], width: 44, height: 44, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined))
                              : Icon(it['item_type'] == 'frame' ? Icons.crop_square_rounded : Icons.military_tech_rounded, size: 36),
                          title: Text(it['name'] ?? ''),
                          subtitle: Text(it['item_type'] == 'frame' ? 'Bingkai' : 'Lencana'),
                          trailing: it['item_type'] == 'frame'
                              ? OutlinedButton(
                                  onPressed: () => _toggleFrame(it),
                                  child: Text(equippedFrame == it['item_id'] ? 'Lepas' : 'Pakai'))
                              : null,
                        ),
                      ),
                  ],
                ),
    );
  }
}

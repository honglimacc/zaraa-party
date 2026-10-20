import 'package:flutter/material.dart';

import '../../api.dart';
import '../../theme.dart';

/// Admin ke atas: tiket Customer Service yang belum dibalas.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/admin/tickets') as List;
      if (mounted) setState(() {
        items = r;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _reply(Map t) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t['subject']),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['display_name']} (ID ${t['public_id']})', style: const TextStyle(color: Z.muted)),
          const SizedBox(height: 8),
          Text(t['message']),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 3, decoration: const InputDecoration(labelText: 'Balasan', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.post('/admin/tickets/${t['id']}/reply', {'reply': c.text});
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiket CS')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : items.isEmpty
              ? const Center(child: Text('Tidak ada tiket baru', style: TextStyle(color: Z.muted)))
              : ListView(children: [
                  for (final t in items)
                    ListTile(
                      title: Text(t['subject'], style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${t['display_name']}: ${t['message']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _reply(t),
                    ),
                ]),
    );
  }
}

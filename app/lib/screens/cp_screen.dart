import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets_avatar.dart';
import 'user_profile_screen.dart';

/// CP Space: pasangan aktif (lama bersama), permintaan masuk/keluar, ajukan lewat ID.
class CpScreen extends StatefulWidget {
  const CpScreen({super.key});

  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  Map? d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/cp');
      if (mounted) setState(() => d = Map.from(r as Map));
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _do(Future<dynamic> Function() f, [String? ok]) async {
    try {
      await f();
      if (ok != null && mounted) toast(context, ok);
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _requestById() async {
    final c = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajukan CP'),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ID pengguna')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: Text(L.t('send'))),
        ],
      ),
    );
    if (id != null && id.trim().isNotEmpty) _do(() => Api.i.post('/cp/request', {'public_id': int.tryParse(id.trim()) ?? 0}), 'Permintaan terkirim');
  }

  Future<void> _breakUp(int cpId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Putuskan CP?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Putuskan')),
        ],
      ),
    );
    if (ok == true) _do(() => Api.i.delete('/cp/$cpId'));
  }

  @override
  Widget build(BuildContext context) {
    final x = d;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('cp'))),
      body: x == null
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (x['partner'] != null) _partner(x['partner']) else _empty(),
                if ((x['incoming'] as List).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Permintaan masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  for (final r in x['incoming'])
                    ListTile(
                      leading: Av(r['user']['avatar_url']),
                      title: Text(r['user']['display_name']),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.red), onPressed: () => _do(() => Api.i.delete('/cp/${r['id']}'))),
                        IconButton(icon: const Icon(Icons.check_circle_rounded, color: Z.mint), onPressed: () => _do(() => Api.i.post('/cp/${r['id']}/accept'), 'CP diterima')),
                      ]),
                    ),
                ],
                if ((x['outgoing'] as List).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Permintaan terkirim', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  for (final r in x['outgoing'])
                    ListTile(
                      leading: Av(r['user']['avatar_url']),
                      title: Text(r['user']['display_name']),
                      subtitle: const Text('Menunggu jawaban'),
                      trailing: TextButton(onPressed: () => _do(() => Api.i.delete('/cp/${r['id']}')), child: Text(L.t('cancel'))),
                    ),
                ],
              ]),
            ),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: const Color(0xFFFFEEF5), borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const Icon(Icons.favorite_border_rounded, size: 60, color: Color(0xFFFF4D8D)),
          const SizedBox(height: 10),
          const Text('Belum punya CP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _requestById, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D8D)), child: const Text('Ajukan lewat ID')),
        ]),
      );

  Widget _partner(Map p) {
    final since = DateTime.tryParse('${p['since']}')?.toLocal();
    final days = since == null ? 0 : DateTime.now().difference(since).inDays + 1;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFFFD1E3), Color(0xFFE5D4FF)]),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: p['user']['id']))),
          child: Av(p['user']['avatar_url'], r: 44),
        ),
        const SizedBox(height: 10),
        Text(p['user']['display_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Bersama $days hari${since != null ? ' • sejak ${DateFormat('d MMM y').format(since)}' : ''}'),
        const SizedBox(height: 12),
        TextButton(onPressed: () => _breakUp(p['id']), child: const Text('Putuskan CP', style: TextStyle(color: Colors.red))),
      ]),
    );
  }
}

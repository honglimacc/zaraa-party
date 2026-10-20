import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../auth_state.dart';
import '../../theme.dart';

/// Panel Admin: cari pengguna, blokir. Super Admin ke atas: ubah peran & koin.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List users = [];
  Map? stats;
  final q = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.i.get('/admin/users', query: {'q': q.text.trim()}),
        Api.i.get('/admin/stats'),
      ]);
      if (mounted) setState(() {
        users = r[0] as List;
        stats = r[1] as Map;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _act(Future<dynamic> Function() f, String okMsg) async {
    try {
      await f();
      if (mounted) toast(context, okMsg);
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<String?> _ask(String title, {bool number = false}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, keyboardType: number ? const TextInputType.numberWithOptions(signed: true) : null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  void _manage(Map u) {
    final auth = context.read<AuthState>();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(u['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('ID ${u['public_id']} • ${AuthState.roleLabel(u['role'])} • ${Z.num(u['coins'])} koin'),
          ),
          ListTile(
            leading: Icon(u['banned'] == true ? Icons.lock_open_rounded : Icons.block_rounded),
            title: Text(u['banned'] == true ? 'Buka blokir' : 'Blokir pengguna'),
            onTap: () {
              Navigator.pop(context);
              _act(() => Api.i.post('/admin/users/${u['id']}/ban', {'banned': u['banned'] != true}), 'Selesai');
            },
          ),
          if (auth.isSuperAdmin) ...[
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: const Text('Ubah peran'),
              onTap: () async {
                Navigator.pop(context);
                final role = await showDialog<String>(
                  context: context,
                  builder: (_) => SimpleDialog(title: const Text('Pilih peran'), children: [
                    for (final r in const ['user', 'admin', 'super_admin', 'developer'])
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text(AuthState.roleLabel(r))),
                  ]),
                );
                if (role != null) _act(() => Api.i.post('/admin/users/${u['id']}/role', {'role': role}), 'Peran diubah');
              },
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on_rounded),
              title: const Text('Tambah / kurangi koin'),
              onTap: () async {
                Navigator.pop(context);
                final v = await _ask('Jumlah koin (negatif untuk mengurangi)', number: true);
                final n = int.tryParse(v ?? '');
                if (n != null && n != 0) _act(() => Api.i.post('/admin/users/${u['id']}/coins', {'amount': n}), 'Koin diperbarui');
              },
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Column(children: [
        if (stats != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              _stat('Pengguna', stats!['users']),
              _stat('Diblokir', stats!['banned']),
              _stat('Room aktif', stats!['rooms']),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: q,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Cari username / nama / ID',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: Z.mint))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i] as Map;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: Text(u['display_name'] ?? ''),
                      subtitle: Text('@${u['username']} • ID ${u['public_id']} • ${AuthState.roleLabel(u['role'])}'),
                      trailing: u['banned'] == true ? const Icon(Icons.block_rounded, color: Colors.red) : null,
                      onTap: () => _manage(u),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _stat(String label, dynamic v) => Expanded(
        child: Card(
          elevation: 0,
          color: const Color(0xFFE3F9F1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: Z.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

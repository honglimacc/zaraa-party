import 'package:flutter/material.dart';

import '../api.dart';
import '../auth_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets_avatar.dart';
import 'chat_screen.dart';

/// Profil pengguna lain: ikuti / berhenti, kirim pesan, ajukan CP.
class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map? u;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/users/${widget.userId}');
      if (mounted) setState(() => u = Map.from(r as Map));
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => busy = true);
    try {
      final following = u!['is_following'] == true;
      final r = following ? await Api.i.delete('/users/${widget.userId}/follow') : await Api.i.post('/users/${widget.userId}/follow');
      setState(() {
        u!['is_following'] = r['is_following'];
        u!['fans'] = (u!['fans'] as int) + (following ? -1 : 1);
      });
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _requestCp() async {
    try {
      await Api.i.post('/cp/request', {'public_id': u!['public_id']});
      if (mounted) toast(context, 'Permintaan CP terkirim');
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = u;
    return Scaffold(
      appBar: AppBar(title: Text(x?['display_name'] ?? '')),
      body: x == null
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : ListView(padding: const EdgeInsets.all(24), children: [
              Center(child: Av(x['avatar_url'], r: 48)),
              const SizedBox(height: 14),
              Center(child: Text(x['display_name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              const SizedBox(height: 4),
              Center(child: Text('ID:${x['public_id']}  •  ${AuthState.roleLabel(x['role'])}', style: const TextStyle(color: Z.muted))),
              if ((x['bio'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(child: Text(x['bio'], textAlign: TextAlign.center)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                _stat(L.t('following'), x['following']),
                _stat(L.t('fans'), x['fans']),
                _stat(L.t('level'), x['level']),
              ]),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _toggleFollow,
                style: FilledButton.styleFrom(backgroundColor: x['is_following'] == true ? Z.muted : Z.mint, minimumSize: const Size.fromHeight(48)),
                child: Text(x['is_following'] == true ? L.t('unfollow') : L.t('follow')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peer: {'id': x['id'], 'display_name': x['display_name']}))),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(L.t('message')),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _requestCp,
                icon: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF4D8D)),
                label: const Text('Ajukan CP'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ]),
    );
  }

  Widget _stat(String label, dynamic v) => Expanded(
        child: Column(children: [
          Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(label, style: const TextStyle(color: Z.muted)),
        ]),
      );
}

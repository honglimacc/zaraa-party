import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../uploader.dart';
import '../widgets_avatar.dart';

/// Ubah foto profil (unggah dari galeri), nama, dan bio.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name;
  late final TextEditingController bio;
  String? avatar;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthState>().me!;
    name = TextEditingController(text: me['display_name']);
    bio = TextEditingController(text: me['bio'] ?? '');
    avatar = me['avatar_url'];
  }

  Future<void> _pick() async {
    final url = await pickAndUpload(context);
    if (url != null) setState(() => avatar = url);
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await Api.i.put('/me', {'display_name': name.text, 'bio': bio.text, if (avatar != null) 'avatar_url': avatar});
      if (!mounted) return;
      await context.read<AuthState>().refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Profil')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(
          child: GestureDetector(
            onTap: _pick,
            child: Stack(children: [
              Av(avatar, r: 52),
              const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 16, backgroundColor: Z.mint, child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white))),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        TextField(controller: name, maxLength: 30, decoration: const InputDecoration(labelText: 'Nama tampilan', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: bio, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: Z.mint, minimumSize: const Size.fromHeight(50)),
          child: Text(L.t('save')),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../l10n.dart';
import '../theme.dart';

/// Undang teman: kode = ID publik. Teman memasukkannya saat mendaftar; kedua pihak mendapat koin.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  Map? d;

  @override
  void initState() {
    super.initState();
    Api.i.get('/earn/invite').then((r) {
      if (mounted) setState(() => d = Map.from(r as Map));
    }).catchError((e) {
      if (mounted) toast(context, '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final x = d;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('invite'))),
      body: x == null
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : ListView(padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.card_giftcard_rounded, size: 72, color: Color(0xFFF2657A)),
              const SizedBox(height: 12),
              Text(
                'Ajak temanmu! Kamu dapat ${Z.num(x['reward']['inviter'])} koin dan temanmu dapat ${Z.num(x['reward']['invitee'])} koin saat mereka mendaftar dengan kodemu.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFE3F9F1), borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  const Text('Kode undanganmu', style: TextStyle(color: Z.muted)),
                  const SizedBox(height: 6),
                  Text(x['code'], style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: x['code']));
                      toast(context, 'Kode disalin');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Salin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Z.mint),
                    onPressed: () => Share.share('Ayo gabung Zaraa Party! Daftar dan masukkan kode undangan ${x['code']} untuk dapat koin gratis.'),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Bagikan'),
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              Row(children: [
                _stat('Teman diundang', '${x['invited']}'),
                _stat('Koin didapat', Z.num(x['total_earned'])),
              ]),
            ]),
    );
  }

  Widget _stat(String l, String v) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: Z.muted)),
        ]),
      );
}

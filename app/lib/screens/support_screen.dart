import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../l10n.dart';
import '../theme.dart';

/// Customer Service: kontak resmi (diatur Developer) + kirim tiket dan lihat balasan.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map? d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/support');
      if (mounted) setState(() => d = Map.from(r as Map));
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) toast(context, 'Tidak bisa membuka tautan');
  }

  Future<void> _newTicket() async {
    final subject = TextEditingController();
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tiket baru'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subject, maxLength: 100, decoration: const InputDecoration(labelText: 'Judul')),
          TextField(controller: msg, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Masalah kamu')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(L.t('send'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.post('/support/tickets', {'subject': subject.text, 'message': msg.text});
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = d;
    final contact = (x?['contact'] ?? {}) as Map;
    final wa = (contact['whatsapp'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
    final mail = (contact['email'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(L.t('support'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        backgroundColor: Z.mint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Tiket baru'),
      ),
      body: x == null
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                if (wa.isNotEmpty) ListTile(leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)), title: const Text('WhatsApp CS'), subtitle: Text('+$wa'), onTap: () => _open('https://wa.me/$wa')),
                if (mail.isNotEmpty) ListTile(leading: const Icon(Icons.email_rounded), title: const Text('Email'), subtitle: Text(mail), onTap: () => _open('mailto:$mail')),
                if ((contact['hours'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Jam layanan: ${contact['hours']}', style: const TextStyle(color: Z.muted))),
                const SizedBox(height: 16),
                const Text('Tiket Saya', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if ((x['tickets'] as List).isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada tiket', style: TextStyle(color: Z.muted)))),
                for (final t in x['tickets'])
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF6F7F9),
                    child: ListTile(
                      title: Text(t['subject'], style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(t['reply'] != null ? 'Balasan: ${t['reply']}' : t['message'], maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: Chip(label: Text(t['status'] == 'closed' ? 'Dibalas' : 'Menunggu')),
                    ),
                  ),
              ]),
            ),
    );
  }
}

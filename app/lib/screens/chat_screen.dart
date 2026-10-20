import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../l10n.dart';
import '../realtime.dart';
import '../theme.dart';

/// Obrolan pribadi dengan satu pengguna. [peer] butuh minimal: id, display_name.
class ChatScreen extends StatefulWidget {
  final Map peer;
  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map> msgs = []; // urutan lama -> baru
  final input = TextEditingController();
  final scroll = ScrollController();
  StreamSubscription? _sub;
  bool sending = false;

  int get peerId => widget.peer['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = Rt.i.dmStream.stream.listen((m) {
      if (m['sender_id'] == peerId && mounted) {
        setState(() => msgs.add(Map.from(m)));
        _bottom();
        Api.i.get('/dm/$peerId').then((_) => Rt.i.refreshUnread()).catchError((_) {}); // tandai terbaca
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/dm/$peerId') as List;
      if (!mounted) return;
      setState(() => msgs = r.reversed.map((e) => Map.from(e as Map)).toList());
      _bottom();
      Rt.i.refreshUnread();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final m = await Api.i.post('/dm/$peerId', {'text': t});
      input.clear();
      setState(() => msgs.add(Map.from(m)));
      _bottom();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthState>().me!['id'];
    return Scaffold(
      appBar: AppBar(title: Text(widget.peer['display_name'] ?? '')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            itemCount: msgs.length,
            itemBuilder: (_, i) {
              final m = msgs[i];
              final mine = m['sender_id'] == myId;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: mine ? Z.mint : const Color(0xFFEFF1F4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(m['text'] ?? '', style: TextStyle(color: mine ? Colors.white : Z.text, fontSize: 15)),
                ),
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
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(onPressed: _send, tooltip: L.t('send'), icon: const Icon(Icons.send_rounded, color: Z.mint)),
            ]),
          ),
        ),
      ]),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../realtime.dart';
import '../theme.dart';
import '../widgets_avatar.dart';
import 'chat_screen.dart';

/// Tab Pesan: daftar percakapan pribadi, diperbarui real-time.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List items = [];
  bool loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = Rt.i.dmStream.stream.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/dm/conversations') as List;
      if (mounted) setState(() {
        items = r;
        loading = false;
      });
      Rt.i.refreshUnread();
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('messages')), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 140),
                      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Z.muted),
                      SizedBox(height: 12),
                      Center(child: Text('Belum ada percakapan', style: TextStyle(color: Z.muted))),
                    ])
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final c = items[i] as Map;
                        final unread = c['unread'] as int? ?? 0;
                        return ListTile(
                          leading: Av(c['avatar_url'], r: 26),
                          title: Text(c['display_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(c['last_text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                )
                              : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peer: Map.from(c))));
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

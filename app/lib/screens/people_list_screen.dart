import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets_avatar.dart';
import 'user_profile_screen.dart';

/// Daftar Following / Fans / Visitors. [kind]: following | fans | visitors.
class PeopleListScreen extends StatefulWidget {
  final String kind;
  final String title;
  const PeopleListScreen({super.key, required this.kind, required this.title});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Api.i.get('/me/people/${widget.kind}').then((r) {
      if (mounted) setState(() {
        items = r as List;
        loading = false;
      });
    }).catchError((e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : items.isEmpty
              ? const Center(child: Text('Belum ada', style: TextStyle(color: Z.muted)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i] as Map;
                    return ListTile(
                      leading: Av(p['avatar_url'], r: 24),
                      title: Text(p['display_name'] ?? ''),
                      subtitle: Text('ID:${p['public_id']}  •  Lv ${p['level']}'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: p['id']))),
                    );
                  },
                ),
    );
  }
}

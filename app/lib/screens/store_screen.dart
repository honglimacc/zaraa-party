import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../theme.dart';

/// Store: tab Bingkai, VIP/SVIP, dan Koin. Isinya dikelola Developer.
class StoreScreen extends StatefulWidget {
  final int initialTab;
  const StoreScreen({super.key, this.initialTab = 0});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List frames = [], tiers = [], packages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.i.get('/catalog/frames'),
        Api.i.get('/catalog/vip-tiers'),
        Api.i.get('/catalog/coin-packages'),
      ]);
      if (mounted) setState(() {
        frames = r[0] as List;
        tiers = r[1] as List;
        packages = r[2] as List;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _buy(String type, Map item, num price) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Beli ${item['name']}?'),
        content: Text('Harga ${Z.num(price)} koin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Beli')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await Api.i.post('/shop/buy', {'type': type, 'id': item['id']});
      if (!mounted) return;
      context.read<AuthState>().setCoins(r['coins']);
      toast(context, 'Pembelian berhasil');
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<AuthState>().me?['coins'];
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Store'),
          actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('${Z.num(coins)} koin', style: const TextStyle(fontWeight: FontWeight.w800, color: Z.gold))))],
          bottom: const TabBar(tabs: [Tab(text: 'Bingkai'), Tab(text: 'VIP / SVIP'), Tab(text: 'Koin')]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: Z.mint))
            : TabBarView(children: [
                _list(frames, Icons.crop_square_rounded, (f) => '${Z.num(f['price'])} koin', (f) => _buy('frame', f, f['price'])),
                _list(tiers, Icons.workspace_premium_rounded, (t) => '${t['kind']} • ${t['duration_days']} hari • ${Z.num(t['price_coins'])} koin', (t) => _buy('vip', t, t['price_coins'])),
                _list(packages, Icons.monetization_on_rounded, (p) => '${Z.num(p['coins'])} koin • Rp ${Z.num(p['price_idr'])}',
                    (_) => toast(context, 'Pembayaran top-up belum tersedia')),
              ]),
      ),
    );
  }

  Widget _list(List items, IconData icon, String Function(Map) sub, void Function(Map) onTap) {
    if (items.isEmpty) return const Center(child: Text('Belum ada item', style: TextStyle(color: Z.muted)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = items[i] as Map;
        final img = (it['image_url'] ?? it['badge_url'] ?? '').toString();
        return Container(
          decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: img.isNotEmpty ? Image.network(img, width: 44, height: 44, errorBuilder: (_, __, ___) => Icon(icon, size: 36)) : Icon(icon, size: 36, color: const Color(0xFFFFA63D)),
            title: Text(it['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub(it)),
            trailing: FilledButton(onPressed: () => onTap(it), style: FilledButton.styleFrom(backgroundColor: Z.mint), child: const Text('Beli')),
          ),
        );
      },
    );
  }
}

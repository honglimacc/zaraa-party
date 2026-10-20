import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth_state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'invite_screen.dart';

/// Earn Cash: check-in harian berantai + riwayat koin + jalan pintas ke undangan.
class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  Map? st;
  List history = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.i.get('/earn/checkin'), Api.i.get('/me/coin-history')]);
      if (mounted) setState(() {
        st = Map.from(r[0] as Map);
        history = r[1] as List;
      });
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _checkin() async {
    setState(() => busy = true);
    try {
      final r = await Api.i.post('/earn/checkin');
      if (!mounted) return;
      context.read<AuthState>().setCoins(r['coins']);
      toast(context, 'Check-in berhasil! +${r['reward']} koin');
      await _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('earn'))),
      body: s == null
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _checkinCard(s),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: const Color(0xFFFFF1F3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF2657A)),
                  title: const Text('Undang teman, dapat koin'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen())),
                ),
                const SizedBox(height: 20),
                const Text('Riwayat Koin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if (history.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada riwayat', style: TextStyle(color: Z.muted)))),
                for (final h in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h['reason'] ?? ''),
                    subtitle: Text(DateFormat('d MMM y, HH:mm').format(DateTime.parse(h['created_at']).toLocal())),
                    trailing: Text('${(h['amount'] as int) > 0 ? '+' : ''}${Z.num(h['amount'])}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: (h['amount'] as int) > 0 ? const Color(0xFF1E9E5A) : Colors.red)),
                  ),
              ]),
            ),
    );
  }

  Widget _checkinCard(Map s) {
    final rewards = (s['rewards'] as List).cast<int>();
    final streak = s['streak'] as int;
    final done = s['checked_in_today'] == true;
    final doneCount = streak % rewards.length == 0 && streak > 0 ? rewards.length : streak % rewards.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFFFD27A), Color(0xFFFFB866)]),
      ),
      child: Column(children: [
        Text('Check-in Harian  •  Beruntun $streak hari', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Z.gold)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < rewards.length; i++)
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: i < doneCount ? Colors.white54 : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text('Hari ${i + 1}', style: const TextStyle(fontSize: 11, color: Z.muted)),
                Icon(i < doneCount ? Icons.check_circle_rounded : Icons.monetization_on_rounded, color: i < doneCount ? Colors.green : const Color(0xFFFFC107)),
                Text('${rewards[i]}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: done || busy ? null : _checkin,
          style: FilledButton.styleFrom(backgroundColor: Z.gold, minimumSize: const Size.fromHeight(46)),
          child: Text(done ? 'Sudah check-in hari ini' : 'Check-in sekarang'),
        ),
      ]),
    );
  }
}

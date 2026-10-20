import 'package:flutter/material.dart';

import '../theme.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'rooms_screen.dart';

/// Kerangka utama: 3 tab di bawah (Home, Pesan, Saya) seperti pada desain acuan.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [RoomsScreen(), MessagesScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 68,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(0, Icons.home_rounded),
              _item(1, Icons.mail_rounded, badge: 11),
              _item(2, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData? icon, {int badge = 0}) {
    final selected = _tab == i;
    Widget child;
    if (icon == null) {
      // Tab "Saya": lingkaran hijau dengan dua mata saat aktif.
      child = Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected ? Z.mint : const Color(0xFFC9CDD4),
          shape: BoxShape.circle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(radius: 4, backgroundColor: Colors.white),
            SizedBox(width: 9),
            CircleAvatar(radius: 4, backgroundColor: Colors.white),
          ],
        ),
      );
    } else {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 44, color: selected ? Z.mint : const Color(0xFFB8BEC8)),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: SizedBox(width: 80, child: Center(child: child)),
    );
  }
}

import 'package:flutter/material.dart';

/// Avatar bulat dengan cadangan ikon bila belum ada foto.
class Av extends StatelessWidget {
  final String? url;
  final double r;
  const Av(this.url, {super.key, this.r = 22});

  @override
  Widget build(BuildContext context) {
    final has = (url ?? '').isNotEmpty;
    return CircleAvatar(
      radius: r,
      backgroundColor: const Color(0xFFE3E8EE),
      backgroundImage: has ? NetworkImage(url!) : null,
      child: has ? null : Icon(Icons.person_rounded, size: r, color: Colors.white),
    );
  }
}

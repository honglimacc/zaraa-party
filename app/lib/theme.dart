import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Warna dan gaya Zaraa Party (mengikuti nuansa halaman Profil pada desain acuan).
class Z {
  static const mint = Color(0xFF00E0A0);
  static const text = Color(0xFF1B1B1F);
  static const muted = Color(0xFF8A8F98);
  static const bgTop = Color(0xFFDFF3FF);
  static const gold = Color(0xFF7A3E00);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: mint),
        scaffoldBackgroundColor: Colors.white,
      );

  static final _fmt = NumberFormat('#,###');
  static String num(dynamic v) => _fmt.format(int.tryParse('${v ?? 0}') ?? 0);
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));

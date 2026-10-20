import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Efek layar penuh saat gift dikirim. Urutan pilihan:
///  1. animation_url berakhiran .json  -> animasi Lottie
///  2. animation_url lain (gif/webp/png) -> gambar animasi
///  3. tanpa animasi -> efek bawaan: ikon gift membesar + hujan partikel
/// Developer mengatur animation_url tiap gift dari Developer Panel.
class GiftEffect extends StatefulWidget {
  final Map gift;
  final int qty;
  const GiftEffect({super.key, required this.gift, this.qty = 1});

  @override
  State<GiftEffect> createState() => _GiftEffectState();
}

class _GiftEffectState extends State<GiftEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  final _rnd = math.Random();
  late final List<double> _seeds = List.generate(14, (_) => _rnd.nextDouble());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _icon(double size) {
    final url = (widget.gift['icon_url'] ?? '').toString();
    return url.isNotEmpty
        ? Image.network(url, width: size, height: size, errorBuilder: (_, __, ___) => Text('🎁', style: TextStyle(fontSize: size * 0.8)))
        : Text('🎁', style: TextStyle(fontSize: size * 0.8));
  }

  Widget _builtIn() {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final pop = Curves.elasticOut.transform((t * 2).clamp(0.0, 1.0).toDouble());
        final fade = t > 0.8 ? (1 - t) / 0.2 : 1.0;
        return Opacity(
          opacity: fade.clamp(0.0, 1.0).toDouble(),
          child: LayoutBuilder(builder: (_, box) {
            return Stack(children: [
              for (var i = 0; i < _seeds.length; i++)
                Positioned(
                  left: box.maxWidth * _seeds[i],
                  top: box.maxHeight * (0.85 - 0.8 * ((t + _seeds[i]) % 1.0)),
                  child: Opacity(opacity: 0.8, child: Text(i.isEven ? '✨' : '💖', style: TextStyle(fontSize: 18 + 14 * _seeds[(i + 3) % _seeds.length]))),
                ),
              Center(child: Transform.scale(scale: pop, child: _icon(140))),
            ]);
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final anim = (widget.gift['animation_url'] ?? '').toString();
    Widget body;
    if (anim.endsWith('.json')) {
      body = Lottie.network(anim, repeat: false, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _builtIn());
    } else if (anim.isNotEmpty) {
      body = Center(child: Image.network(anim, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _builtIn()));
    } else {
      body = _builtIn();
    }
    return IgnorePointer(child: body);
  }
}

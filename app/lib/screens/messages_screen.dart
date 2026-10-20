import 'package:flutter/material.dart';

import '../theme.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesan'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Z.muted),
            SizedBox(height: 12),
            Text('Pesan pribadi segera hadir', style: TextStyle(color: Z.muted)),
          ],
        ),
      ),
    );
  }
}

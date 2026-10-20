import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState()..init(),
      child: const ZaraaApp(),
    ),
  );
}

class ZaraaApp extends StatelessWidget {
  const ZaraaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zaraa Party',
      debugShowCheckedModeBanner: false,
      theme: Z.theme(),
      home: Consumer<AuthState>(
        builder: (_, auth, __) {
          if (!auth.ready) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Z.mint)));
          }
          return auth.me == null ? const LoginScreen() : const HomeShell();
        },
      ),
    );
  }
}

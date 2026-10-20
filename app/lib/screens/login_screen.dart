import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _invite = TextEditingController();
  bool _register = false;
  bool _busy = false;

  Future<void> _submit() async {
    final auth = context.read<AuthState>();
    setState(() => _busy = true);
    try {
      if (_register) {
        await auth.register(_user.text.trim(), _pass.text, _name.text.trim(), inviteCode: _invite.text.trim());
      } else {
        await auth.login(_user.text.trim(), _pass.text);
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Z.bgTop, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(color: Z.mint, shape: BoxShape.circle),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 16),
                  const Text('Zaraa Party', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Z.text)),
                  const SizedBox(height: 4),
                  const Text('Ngobrol suara bareng teman', style: TextStyle(color: Z.muted)),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    _field(_name, 'Nama tampilan', Icons.badge_outlined),
                    const SizedBox(height: 12),
                  ],
                  _field(_user, 'Username', Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(_pass, 'Password', Icons.lock_outline, obscure: true),
                  if (_register) ...[
                    const SizedBox(height: 12),
                    _field(_invite, 'Kode undangan (opsional)', Icons.card_giftcard_rounded),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Z.mint,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_register ? 'Daftar' : 'Masuk', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false}) => TextField(
        controller: c,
        obscureText: obscure,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      );
}

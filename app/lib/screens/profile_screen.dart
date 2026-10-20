import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../theme.dart';
import 'admin/users_screen.dart';
import 'developer/developer_panel.dart';
import 'my_items_screen.dart';
import 'store_screen.dart';

/// Halaman Profil — tata letak mengikuti desain acuan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AuthState>().refresh().catchError((_) {}));
  }

  void _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) context.read<AuthState>().refresh().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final me = auth.me!;
    final vip = me['vip'] as Map?;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Z.bgTop, Color(0xFFF6F7F9)],
          stops: [0, 0.45],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: auth.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _header(me, auth),
              const SizedBox(height: 22),
              _stats(me),
              const SizedBox(height: 18),
              _walletAndCards(me, vip),
              const SizedBox(height: 16),
              _menu(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Map me, AuthState auth) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: me['frame_id'] != null ? Border.all(color: const Color(0xFFFFC53D), width: 3) : null,
          ),
          child: CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFE3E8EE),
            backgroundImage: (me['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(me['avatar_url']) : null,
            child: (me['avatar_url'] ?? '').toString().isEmpty
                ? const Icon(Icons.person_rounded, size: 40, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      me['display_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Z.text),
                    ),
                  ),
                  if (auth.role != 'user') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Z.mint, borderRadius: BorderRadius.circular(10)),
                      child: Text(AuthState.roleLabel(auth.role),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '${me['public_id']}'));
                  toast(context, 'ID disalin');
                },
                child: Row(
                  children: [
                    Text('ID:${me['public_id']}', style: const TextStyle(color: Z.muted, fontSize: 15)),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_rounded, size: 16, color: Z.muted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Z.muted),
      ],
    );
  }

  Widget _stats(Map me) {
    Widget cell(String label, dynamic v) => Expanded(
          child: Column(
            children: [
              Text('$v', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: Z.text)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Z.muted, fontSize: 16)),
            ],
          ),
        );
    return Row(children: [cell('Following', me['following']), cell('Fans', me['fans']), cell('Visitors', me['visitors'])]);
  }

  Widget _walletAndCards(Map me, Map? vip) {
    return Stack(
      children: [
        // Kartu Wallet (oranye) yang sebagian tertutup panel putih.
        GestureDetector(
          onTap: () => _go(const StoreScreen(initialTab: 2)),
          child: Container(
            height: 120,
            padding: const EdgeInsets.fromLTRB(22, 14, 18, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Color(0xFFFFD27A), Color(0xFFFFB866)]),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Z.gold)),
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('C', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20)),
                ),
                const SizedBox(width: 4),
                Text(Z.num(me['coins']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Z.gold)),
                const Icon(Icons.chevron_right_rounded, color: Z.gold),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 52),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _go(const StoreScreen(initialTab: 1)),
                child: Container(
                  height: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF8DEBB0), width: 2),
                    gradient: const LinearGradient(colors: [Color(0xFFD4FFD9), Color(0xFFBDF7CE)]),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vip?['kind'] ?? 'SVIP',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF176B2C))),
                            const SizedBox(height: 4),
                            Text(vip != null ? '${vip['name']} aktif' : 'Activate SVIP',
                                style: const TextStyle(fontSize: 17, color: Color(0xFF4FA865))),
                          ],
                        ),
                      ),
                      const Icon(Icons.workspace_premium_rounded, size: 56, color: Color(0xFF6B7A72)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _smallCard(
                      'Level',
                      const Color(0xFFE0ECFF),
                      const Color(0xFF3B4C9B),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF6B7A8F), borderRadius: BorderRadius.circular(14)),
                        child: Text('${me['level']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _smallCard(
                      'Badges',
                      const Color(0xFFEBE2FF),
                      const Color(0xFF6B45B8),
                      Text('*${me['badge_count']}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF6B45B8))),
                      () => _go(const MyItemsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallCard(String title, Color bg, Color fg, Widget trailing, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fg.withOpacity(0.18), width: 2),
          ),
          child: Row(
            children: [
              Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: fg)),
              const Spacer(),
              trailing,
            ],
          ),
        ),
      );

  Widget _menu(AuthState auth) {
    final soon = () => toast(context, 'Segera hadir');
    final items = <_MenuItem>[
      _MenuItem('Invite Friends', Icons.card_giftcard_rounded, const Color(0xFFF2657A), soon),
      _MenuItem('Earn Cash', Icons.savings_rounded, const Color(0xFFF2B01E), soon),
      _MenuItem('CP Space', Icons.favorite_rounded, const Color(0xFFFF4D8D), soon),
      _MenuItem('My Items', Icons.shopping_bag_rounded, const Color(0xFFC77DFF), () => _go(const MyItemsScreen())),
      _MenuItem('Store', Icons.storefront_rounded, const Color(0xFFFFA63D), () => _go(const StoreScreen())),
      _MenuItem('Customer Service', Icons.headset_mic_rounded, const Color(0xFF7C6BE0), soon),
      _MenuItem('Language', Icons.language_rounded, const Color(0xFF4A90E2), soon, trailing: 'English'),
      if (auth.isStaff) _MenuItem('Admin Panel', Icons.admin_panel_settings_rounded, const Color(0xFF00B887), () => _go(const UsersScreen())),
      if (auth.isDeveloper) _MenuItem('Developer Panel', Icons.code_rounded, const Color(0xFF222B45), () => _go(const DeveloperPanel())),
      _MenuItem('Logout', Icons.logout_rounded, const Color(0xFF8A8F98), () => auth.logout()),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final m in items)
            InkWell(
              onTap: m.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(
                  children: [
                    Icon(m.icon, color: m.color, size: 30),
                    const SizedBox(width: 18),
                    Expanded(child: Text(m.title, style: const TextStyle(fontSize: 19, color: Z.text))),
                    if (m.trailing != null) Text(m.trailing!, style: const TextStyle(color: Z.muted, fontSize: 16)),
                    const Icon(Icons.chevron_right_rounded, color: Z.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? trailing;
  _MenuItem(this.title, this.icon, this.color, this.onTap, {this.trailing});
}

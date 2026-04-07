import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/auth/user_session.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  bool _isWebWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    final isWide = _isWebWide(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İl MEM Yönetim'),
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await context.read<UserSession>().load(); // session reset
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide) const _SideMenu(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isWide ? null : const _BottomNav(),
      drawer: isWide ? null : const Drawer(child: _SideMenu()),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();

    return SizedBox(
      width: 260,
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Menü')),

          _item(context, 'Anasayfa', '/dashboard'),
          _item(context, 'Okullar', '/schools'),
          _item(context, 'Personel', '/staff'),
          _item(context, 'Öğrenciler', '/students'),
          _item(context, 'Projeler', '/projects'),
          _item(context, 'Denetim', '/inspection'),
          _item(context, 'Harita', '/maps'),
          _item(context, 'Duyurular', '/announcements'),
          _item(context, 'Talepler', '/requests'),

          // ✅ Admin özel menüler (en altta)
          if (session.isAdmin) ...[
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'Yönetici',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _item(context, 'Yönetici Ekranı', '/admin'),
            _item(context, 'Planlı Denetimler', '/planli-denetimler'),
          ],
        ],
      ),
    );
  }

  Widget _item(BuildContext context, String title, String route) {
    return ListTile(
      title: Text(title),
      onTap: () {
        Navigator.of(context).maybePop(); // drawer kapat
        context.go(route);
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  int _indexFromLocation(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/schools')) return 1;
    if (location.startsWith('/projects')) return 2;
    if (location.startsWith('/announcements')) return 3;
    if (location.startsWith('/maps')) return 4;
    return 0;
  }

  void _goByIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/schools');
        break;
      case 2:
        context.go('/projects');
        break;
      case 3:
        context.go('/announcements');
        break;
      case 4:
        context.go('/maps');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _goByIndex(context, i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Panel'),
        NavigationDestination(icon: Icon(Icons.school), label: 'Okullar'),
        NavigationDestination(icon: Icon(Icons.work), label: 'Projeler'),
        NavigationDestination(icon: Icon(Icons.campaign), label: 'Duyuru'),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Harita'),
      ],
    );
  }
}

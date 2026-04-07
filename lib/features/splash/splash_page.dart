import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/user_session.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_navigated) return;

    final session = context.watch<UserSession>();
    if (session.loading) return;

    _navigated = true;

    // Oturum yoksa login, varsa dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!session.isLoggedIn || !session.isActive) {
        context.go('/login');
      } else {
        context.go('/dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

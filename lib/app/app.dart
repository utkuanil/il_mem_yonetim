import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'theme.dart';
import '../core/auth/user_session.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔑 UserSession provider’dan okunuyor
    final session = context.read<UserSession>();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'İl MEM Yönetim',
      theme: AppTheme.light,

      // 🔑 router context + session ile kuruluyor
      routerConfig: AppRouter.router(context),
    );
  }
}

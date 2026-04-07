import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:provider/provider.dart' as p;                 // ✅ alias
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope; // ✅ sadece ProviderScope

import 'firebase_options.dart';
import 'app/app.dart';
import 'core/auth/user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root({super.key});

  @override
  Widget build(BuildContext context) {
    return p.ChangeNotifierProvider<UserSession>(
      create: (_) => UserSession()..load(),
      child: const App(),
    );
  }
}

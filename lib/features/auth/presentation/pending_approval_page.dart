import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  Future<Map<String, dynamic>?> _loadMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onay Bekleniyor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Çıkış', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadMe(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data;
          final status = (data?['status'] ?? 'pending').toString();
          final isActive = data?['isActive'] == true;

          String title = 'Hesabınız yönetici onayında';
          String desc =
              'Kayıt oluşturuldu. Yönetici hesabınızı onayladığında giriş yapabilirsiniz.';

          if (status == 'rejected') {
            title = 'Hesabınız reddedildi';
            desc = 'Yönetici hesabınızı reddetti. Lütfen yönetici ile iletişime geçin.';
          } else if (status == 'active' && isActive) {
            title = 'Hesabınız aktif';
            desc = 'Hesabınız onaylandı. Giriş yapabilirsiniz.';
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'rejected'
                            ? Icons.block_outlined
                            : status == 'active' && isActive
                            ? Icons.check_circle_outline
                            : Icons.hourglass_bottom,
                        size: 46,
                      ),
                      const SizedBox(height: 12),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(desc,
                          style: const TextStyle(color: Colors.black54),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Giriş Sayfası'),
                            onPressed: () => context.go('/login'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Kontrol Et'),
                            onPressed: () => (context as Element).markNeedsBuild(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

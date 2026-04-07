import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> register() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text.trim();
      final pass2 = pass2Ctrl.text.trim();

      if (email.isEmpty || pass.isEmpty || pass2.isEmpty) {
        throw 'Tüm alanlar zorunludur.';
      }
      if (pass.length < 6) {
        throw 'Şifre en az 6 karakter olmalı.';
      }
      if (pass != pass2) {
        throw 'Şifreler aynı değil.';
      }

      // 1) Auth'ta kullanıcı oluştur
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw 'Kayıt başarısız (uid yok)';

      // 2) Firestore users/{uid} -> pending oluştur
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'role': 'user',
        'status': 'pending',
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3) Güvenlik / akış: kullanıcıyı çıkış yaptır, admin onayı beklet
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      context.go('/pending-approval');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => error = _mapAuthError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı.';
      case 'invalid-email':
        return 'E-posta formatı hatalı.';
      case 'weak-password':
        return 'Şifre zayıf. Daha güçlü bir şifre deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok gibi görünüyor.';
      default:
        return e.message ?? 'Kayıt hatası oluştu.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Kayıt oluşturulduktan sonra hesabınız yönetici onayına düşer.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: pass2Ctrl,
              decoration: const InputDecoration(labelText: 'Şifre (Tekrar)'),
              obscureText: true,
            ),

            const SizedBox(height: 14),

            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            ElevatedButton.icon(
              onPressed: loading ? null : register,
              icon: loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check_circle_outline),
              label: Text(loading ? 'Oluşturuluyor…' : 'Kayıt Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

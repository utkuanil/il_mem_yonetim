import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // ✅ Yönetici sayfasına dön
        ),
        title: const Text('Raporlar'),
      ),
      body: const Center(
        child: Text(
          'Raporlar (Sadece Admin)',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

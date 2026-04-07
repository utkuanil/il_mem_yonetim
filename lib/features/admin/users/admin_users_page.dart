import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _statusOf(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim();
    if (status.isNotEmpty) return status; // pending/active/rejected

    // eski kullanıcılar: status yoksa isActive’e göre türet
    final isActive = data['isActive'] == true;
    return isActive ? 'active' : 'pending';
  }

  Future<void> _approve(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': 'active',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': 'rejected',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleActive(String uid, bool current) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Beklemede'),
            Tab(text: 'Aktif'),
            Tab(text: 'Reddedilen'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('email')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final docs = snap.data?.docs ?? [];
          final users = docs.map((d) {
            final data = d.data();
            return _UserRow(
              uid: d.id,
              email: (data['email'] ?? '').toString(),
              role: (data['role'] ?? 'user').toString(),
              status: _statusOf(data),
              isActive: data['isActive'] == true,
              createdAt: (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null,
            );
          }).toList();

          final pending = users.where((u) => u.status == 'pending').toList();
          final active = users.where((u) => u.status == 'active').toList();
          final rejected = users.where((u) => u.status == 'rejected').toList();

          // İstersen tarihe göre client-side sırala (index gerekmez)
          int byDate(_UserRow a, _UserRow b) {
            final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          }

          pending.sort(byDate);
          active.sort(byDate);
          rejected.sort(byDate);

          return TabBarView(
            controller: _tab,
            children: [
              _buildList(
                title: 'Onay Bekleyenler',
                items: pending,
                meUid: me?.uid,
                trailingBuilder: (u) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Onayla',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () async {
                        try {
                          await _approve(u.uid);
                          _snack('Onaylandı: ${u.email}');
                        } catch (e) {
                          _snack(e.toString());
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Reddet',
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () async {
                        try {
                          await _reject(u.uid);
                          _snack('Reddedildi: ${u.email}');
                        } catch (e) {
                          _snack(e.toString());
                        }
                      },
                    ),
                  ],
                ),
              ),
              _buildList(
                title: 'Aktif Kullanıcılar',
                items: active,
                meUid: me?.uid,
                trailingBuilder: (u) => IconButton(
                  tooltip: 'Aktif/Pasif',
                  icon: Icon(u.isActive ? Icons.toggle_on : Icons.toggle_off),
                  onPressed: u.uid == me?.uid
                      ? null
                      : () async {
                    try {
                      await _toggleActive(u.uid, u.isActive);
                    } catch (e) {
                      _snack(e.toString());
                    }
                  },
                ),
              ),
              _buildList(
                title: 'Reddedilenler',
                items: rejected,
                meUid: me?.uid,
                trailingBuilder: (u) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Pending'),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(u.uid)
                              .update({
                            'status': 'pending',
                            'isActive': false,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          _snack('Pending’e alındı: ${u.email}');
                        } catch (e) {
                          _snack(e.toString());
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList({
    required String title,
    required List<_UserRow> items,
    required String? meUid,
    required Widget Function(_UserRow u) trailingBuilder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$title yok.'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final u = items[i];
        return ListTile(
          title: Text(u.email.isEmpty ? u.uid : u.email),
          subtitle: Text(
            'role: ${u.role} • status: ${u.status} • aktif: ${u.isActive ? "evet" : "hayır"}',
          ),
          trailing: trailingBuilder(u),
          leading: Icon(
            u.uid == meUid ? Icons.verified_user : Icons.person_outline,
          ),
        );
      },
    );
  }
}

class _UserRow {
  final String uid;
  final String email;
  final String role;
  final String status; // pending/active/rejected
  final bool isActive;
  final DateTime? createdAt;

  _UserRow({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

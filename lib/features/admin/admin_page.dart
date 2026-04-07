import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ✅ Planlı denetimler (Inspection feature)
import '../inspection/models/planli_denetim.dart';
import '../inspection/services/planli_denetim_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Future<void> _toggleActive(String uid, bool current) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // üstte admin kısa aksiyonlar
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AdminActionCard(
                title: 'Raporlar',
                icon: Icons.insert_chart_outlined,
                onTap: () => context.go('/reports'),
              ),
              _AdminActionCard(
                title: 'Analizler',
                icon: Icons.analytics_outlined,
                onTap: () => context.go('/analytics'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Planlı Denetimler kartı
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/planli-denetimler'),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Planlı Denetimler',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/planli-denetimler'),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Tümünü gör'),
                        ),
                        IconButton(
                          tooltip: 'Yenile',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<List<PlanliDenetim>>(
                      future: PlanliDenetimService.fetchAll(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snap.hasError) {
                          return Text('Hata: ${snap.error}');
                        }

                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Planlı denetim bulunamadı.'),
                          );
                        }

                        final shown = list.reversed.take(5).toList();

                        return Column(
                          children: [
                            for (final d in shown) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  d.okulAdi.isEmpty ? '-' : d.okulAdi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${d.ilce.isEmpty ? "-" : d.ilce} • ${d.tarihSaat.isEmpty ? "-" : d.tarihSaat}\n'
                                      'Denetleyen: ${d.denetleyen.isEmpty ? "-" : d.denetleyen}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go('/planli-denetimler'),
                              ),
                              const Divider(height: 1),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ ✅ Kullanıcı Yönetimi (Pending approve/reject sayfasına gider)
          Card(
            child: ListTile(
              leading: const Icon(Icons.supervised_user_circle_outlined),
              title: const Text('Kullanıcı Yönetimi'),
              subtitle: const Text('Onay bekleyenleri onayla / reddet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin-users'),
            ),
          ),


          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // ✅ Kullanıcılar kartı (mevcut liste kalsın)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.people_alt_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Kullanıcılar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy('email')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return Text('Hata: ${snap.error}');
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Henüz kullanıcı profili yok.'),
                        );
                      }

                      return Column(
                        children: [
                          for (final d in docs) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(d.data()['email']?.toString() ?? '-'),
                              subtitle: Text(
                                'role: ${d.data()['role'] ?? '-'}  •  '
                                    'status: ${d.data()['status'] ?? '-'}  •  '
                                    'aktif: ${d.data()['isActive'] == true ? "evet" : "hayır"}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Aktif/Pasif',
                                icon: Icon(
                                  d.data()['isActive'] == true
                                      ? Icons.toggle_on
                                      : Icons.toggle_off,
                                ),
                                onPressed: d.id == me?.uid
                                    ? null
                                    : () async {
                                  try {
                                    await _toggleActive(
                                      d.id,
                                      d.data()['isActive'] == true,
                                    );
                                  } catch (e) {
                                    _snack(e.toString());
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

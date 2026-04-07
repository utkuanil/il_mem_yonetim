import 'package:flutter/material.dart';

import '../models/planli_denetim.dart';
import '../services/planli_denetim_service.dart';
import 'package:go_router/go_router.dart';
class PlanliDenetimlerPage extends StatefulWidget {
  const PlanliDenetimlerPage({super.key});

  @override
  State<PlanliDenetimlerPage> createState() => _PlanliDenetimlerPageState();
}

class _PlanliDenetimlerPageState extends State<PlanliDenetimlerPage> {
  late Future<List<PlanliDenetim>> _future;

  @override
  void initState() {
    super.initState();
    _future = PlanliDenetimService.fetchAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PlanliDenetimService.fetchAll();
    });
    await _future;
  }

  void _showDetail(PlanliDenetim d) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(d.okulAdi.isEmpty ? 'Denetim' : d.okulAdi),
          content: SingleChildScrollView(
            child: Text(
              'ID: ${d.id}\n'
                  'İl: ${d.il}\n'
                  'İlçe: ${d.ilce}\n'
                  'Kurum Kodu: ${d.kurumKodu}\n'
                  'Denetleyen: ${d.denetleyen}\n'
                  'Tarih/Saat: ${d.tarihSaat}\n\n'
                  'Rapor:\n${d.rapor.isEmpty ? "-" : d.rapor}',
            ),
          ),
          actions: [
            TextButton(
              // ✅ MUTLAKA dialogContext ile kapat
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Geri',
          onPressed: () {
            // Eğer geri stack varsa geri dön, yoksa admin’e git
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        title: const Text('Planlı Denetimler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),

      body: FutureBuilder<List<PlanliDenetim>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }

          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Denetim kaydı bulunamadı.'));
          }

          final items = list.reversed.toList(); // son gelen üstte

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = items[i];
                return ListTile(
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
                  onTap: () => _showDetail(d),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

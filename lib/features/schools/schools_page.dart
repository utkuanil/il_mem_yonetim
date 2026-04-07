import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';
import '../../core/models/school.dart';
import 'school_detail_page.dart';

class SchoolsPage extends ConsumerStatefulWidget {
  const SchoolsPage({super.key});

  @override
  ConsumerState<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends ConsumerState<SchoolsPage> {
  List<School> all = [];
  List<School> filtered = [];

  bool loading = true;
  String? error;

  String q = '';
  String district = 'Tümü';

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: true); // ✅ artık GitHub JSON
  }

  List<dynamic> _extractRecords(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final r = decoded['records'];
      if (r is List) return r;
      return const [];
    }
    if (decoded is List) return decoded;
    return const [];
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final decoded = await ref.read(jsonRepositoryProvider).getJson(
        'tunceli_okullar.json',
        forceRefresh: forceRefresh,
        // İstersen refresh'te cacheBust da açabilirsin:
        cacheBust: forceRefresh,
      );

      final records = _extractRecords(decoded);

      final data = records
          .whereType<Map>()
          .map((e) => School.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      data.sort((a, b) {
        final c1 = a.ilce.compareTo(b.ilce);
        if (c1 != 0) return c1;
        return a.okulAdi.compareTo(b.okulAdi);
      });

      debugPrint('GITHUB OKUL SAYISI: ${data.length}');
      if (data.isNotEmpty) {
        debugPrint('ILK OKUL: ${data.first.okulAdi} | Kod: ${data.first.kurumKodu}');
      }

      setState(() {
        all = data;
        filtered = _filterList(data, q, district);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Veri hatası: $e';
      });
    }
  }


  List<School> _filterList(List<School> source, String q, String district) {
    final query = q.trim().toLowerCase();

    return source.where((s) {
      final matchesQuery =
          query.isEmpty ||
              s.okulAdi.toLowerCase().contains(query) ||
              s.kurumKodu.toLowerCase().contains(query);

      final matchesDistrict = district == 'Tümü' || s.ilce == district;

      return matchesQuery && matchesDistrict;
    }).toList();
  }

  void _applyFilter() {
    setState(() {
      filtered = _filterList(all, q, district);
    });
  }

  @override
  Widget build(BuildContext context) {
    final districts = <String>{'Tümü', ...all.map((e) => e.ilce)}
        .where((e) => e.trim().isNotEmpty)
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Okullar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => _load(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    q = v;
                    _applyFilter();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Okul ara (ad / kurum kodu)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: districts.contains(district) ? district : 'Tümü',
                  items: districts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    district = v ?? 'Tümü';
                    _applyFilter();
                  },
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    border: OutlineInputBorder(),
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (error != null)
                ? Center(child: Text(error!))
                : (all.isEmpty)
                ? const Center(child: Text('Kayıt bulunamadı.'))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.school),
                    title: Text(s.okulAdi),
                    subtitle: Text(
                      '${s.ilce} • Kod: ${s.kurumKodu}\n'
                          'Norm: ${s.norm ?? 0}  Kadrolu: ${s.kadrolu ?? 0}  Söz: ${s.sozlesmeli ?? 0}',
                    ),
                    isThreeLine: true,
                    trailing: _NormChipCompact(s),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SchoolDetailPage(school: s),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NormChipCompact extends StatelessWidget {
  final School school;
  const _NormChipCompact(this.school);

  @override
  Widget build(BuildContext context) {
    final fark = school.normFarki;

    late final Color bg;
    late final String text;

    if (fark > 0) {
      bg = Colors.red;
      text = 'Açık: $fark';
    } else if (fark == 0) {
      bg = Colors.green;
      text = 'Dolu';
    } else {
      bg = Colors.orange;
      text = 'Fazla: ${fark.abs()}';
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

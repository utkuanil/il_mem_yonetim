import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';

class DykKurslariPage extends ConsumerStatefulWidget {
  const DykKurslariPage({super.key});

  @override
  ConsumerState<DykKurslariPage> createState() => _DykKurslariPageState();
}

class _DykKurslariPageState extends ConsumerState<DykKurslariPage> {
  static const String _remotePath = 'dyk_kurslari.json';
  late Future<List<_SchoolGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadGrouped();
  }

  Future<List<_SchoolGroup>> _loadGrouped({bool forceRefresh = false}) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      _remotePath,
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    final List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      final r = decoded['records'];
      list = (r is List) ? r : const [];
    } else if (decoded is List) {
      list = decoded;
    } else if (decoded is String) {
      final again = jsonDecode(decoded);
      if (again is Map<String, dynamic>) {
        final r = again['records'];
        list = (r is List) ? r : const [];
      } else if (again is List) {
        list = again;
      } else {
        throw Exception('Beklenmeyen JSON formatı');
      }
    } else {
      throw Exception('Beklenmeyen JSON formatı');
    }

    final records = list
        .whereType<Map<String, dynamic>>()
        .map((e) => _DykRecord.fromJson(e))
        .toList();

    final groups = <String, _SchoolGroup>{};

    for (final r in records) {
      final key = '${r.ilceAdi}||${r.kurumAdi}';
      final g = groups.putIfAbsent(
        key,
            () => _SchoolGroup(ilceAdi: r.ilceAdi, kurumAdi: r.kurumAdi),
      );
      g.items.add(r);
    }

    final result = groups.values.toList();
    for (final g in result) {
      g.kursSayisiToplam = g.items.fold<int>(0, (s, e) => s + e.kursSayisi);
      g.toplamToplam = g.items.fold<int>(0, (s, e) => s + e.toplam);
    }

    result.sort((a, b) {
      final c1 = a.ilceAdi.compareTo(b.ilceAdi);
      if (c1 != 0) return c1;
      return a.kurumAdi.compareTo(b.kurumAdi);
    });

    return result;
  }


  Future<void> _refresh() async {
    setState(() {
      _future = _loadGrouped(forceRefresh: true);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destekleme ve Yetiştirme Kursları'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<_SchoolGroup>>(
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
            return const Center(child: Text('Kayıt bulunamadı.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final g = list[i];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(g.kurumAdi.isNotEmpty ? g.kurumAdi : '-'),
                  subtitle: Text(
                    '${g.ilceAdi.isNotEmpty ? g.ilceAdi : '-'}\n'
                        'Kurs: ${g.kursSayisiToplam} • Ders: ${g.items.length}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${g.toplamToplam}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text('Toplam', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _DykSchoolDetailPage(group: g),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DykSchoolDetailPage extends StatelessWidget {
  final _SchoolGroup group;
  const _DykSchoolDetailPage({required this.group});

  @override
  Widget build(BuildContext context) {
    final items = [...group.items];

    // ✅ Ders adına göre sıralayalım
    items.sort((a, b) => a.dersAdi.compareTo(b.dersAdi));

    return Scaffold(
      appBar: AppBar(
        title: Text(group.kurumAdi.isNotEmpty ? group.kurumAdi : 'Detay'),
      ),
      body: Column(
        children: [
          // Üst özet kartı
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${group.ilceAdi}\n'
                            'Ders: ${group.items.length}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Kurs', value: '${group.kursSayisiToplam}'),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Toplam', value: '${group.toplamToplam}'),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Ders satırları
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(r.dersAdi.isNotEmpty ? r.dersAdi : '-'),
                    subtitle: Text('Kurs: ${r.kursSayisi}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${r.toplam}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text('Toplam', style: TextStyle(fontSize: 11)),
                      ],
                    ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _SchoolGroup {
  final String ilceAdi;
  final String kurumAdi;
  final List<_DykRecord> items = [];

  int kursSayisiToplam = 0;
  int toplamToplam = 0;

  _SchoolGroup({
    required this.ilceAdi,
    required this.kurumAdi,
  });
}

class _DykRecord {
  final String genelMudurluk;
  final String ilceAdi;
  final String kurumAdi;
  final String dersAdi;
  final int kursSayisi;
  final int toplam;

  _DykRecord({
    required this.genelMudurluk,
    required this.ilceAdi,
    required this.kurumAdi,
    required this.dersAdi,
    required this.kursSayisi,
    required this.toplam,
  });

  static String _asString(dynamic v) => v == null ? '' : v.toString().trim();

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  factory _DykRecord.fromJson(Map<String, dynamic> json) {
    return _DykRecord(
      genelMudurluk: _asString(json['GENEL_MUDURLUK']),
      ilceAdi: _asString(json['ILCE_ADI']),
      kurumAdi: _asString(json['KURUM_ADI']),
      dersAdi: _asString(json['DERS_ADI']),
      kursSayisi: _asInt(json['KURS_SAYISI']),
      toplam: _asInt(json['TOPLAM']),
    );
  }
}

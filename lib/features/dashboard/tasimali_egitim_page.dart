import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';
import 'tasimali_okul_detail_page.dart';

class TasimaliEgitimPage extends ConsumerStatefulWidget {
  const TasimaliEgitimPage({super.key});

  @override
  ConsumerState<TasimaliEgitimPage> createState() => _TasimaliEgitimPageState();
}

class _TasimaliEgitimPageState extends ConsumerState<TasimaliEgitimPage> {
  // ✅ GitHub path (repo: /data/tasimali/...)
  static const String _ozelPath = 'tasimali/tasimali_ozel.json';
  static const String _ortaPath = 'tasimali/tasimali_orta.json';
  static const String _temelPath = 'tasimali/tasimali_temel.json';

  late Future<_TasimaliBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAll(forceRefresh: true);
    });
  }


  Future<_TasimaliBundle> _loadAll({bool forceRefresh = false}) async {
    final ozel = await _loadRecords(_ozelPath, forceRefresh: forceRefresh);
    final orta = await _loadRecords(_ortaPath, forceRefresh: forceRefresh);
    final temel = await _loadRecords(_temelPath, forceRefresh: forceRefresh);
    return _TasimaliBundle(ozel: ozel, orta: orta, temel: temel);
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

  Future<List<Map<String, dynamic>>> _loadRecords(
      String remotePath, {
        bool forceRefresh = false,
      }) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      remotePath,
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    final records = _extractRecords(decoded);

    return records
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Taşımalı Eğitim'),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Özel Eğitim'),
              Tab(text: 'Orta Öğretim'),
              Tab(text: 'Temel Eğitim'),
            ],
          ),
        ),
        body: FutureBuilder<_TasimaliBundle>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Hata: ${snap.error}'));
            }

            final data = snap.data;
            if (data == null) {
              return const Center(child: Text('Veri bulunamadı.'));
            }

            return TabBarView(
              children: [
                _OkulList(records: data.ozel, kategori: 'Özel Eğitim'),
                _OkulList(records: data.orta, kategori: 'Orta Öğretim'),
                _OkulList(records: data.temel, kategori: 'Temel Eğitim'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OkulList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final String kategori;

  const _OkulList({required this.records, required this.kategori});

  String _asStr(dynamic v) => v == null ? '' : v.toString().trim();

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('Kayıt bulunamadı.'));
    }

    // MERKEZ_OKULLAR alanına göre grupla
    final Map<String, List<Map<String, dynamic>>> bySchool = {};
    for (final r in records) {
      final school = _asStr(r['MERKEZ_OKULLAR'] ?? r['merkez_okullar']);
      if (school.isEmpty) continue;
      bySchool.putIfAbsent(school, () => []).add(r);
    }

    final schools = bySchool.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: schools.length,
      itemBuilder: (context, i) {
        final schoolName = schools[i];
        final schoolRecords = bySchool[schoolName] ?? const [];

        return Card(
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(schoolName),
            subtitle: Text('Kayıt: ${schoolRecords.length}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TasimaliOkulDetailPage(
                    kategori: kategori,
                    okulAdi: schoolName,
                    rows: schoolRecords,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TasimaliBundle {
  final List<Map<String, dynamic>> ozel;
  final List<Map<String, dynamic>> orta;
  final List<Map<String, dynamic>> temel;

  _TasimaliBundle({
    required this.ozel,
    required this.orta,
    required this.temel,
  });
}

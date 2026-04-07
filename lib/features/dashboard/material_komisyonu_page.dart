import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';

class MaterialKomisyonuPage extends ConsumerStatefulWidget {
  const MaterialKomisyonuPage({super.key});

  @override
  ConsumerState<MaterialKomisyonuPage> createState() => _MaterialKomisyonuPageState();
}

class _MaterialKomisyonuPageState extends ConsumerState<MaterialKomisyonuPage> {
  static const String _remotePath = 'material_komisyonu.json';

  late Future<_KomisyonData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
  }


  Future<_KomisyonData> _load({bool forceRefresh = false}) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      _remotePath,
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh, // opsiyonel ama refresh'te iyi
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Beklenmeyen JSON formatı (Map bekleniyordu)');
    }

    final title = (decoded['title'] ?? 'Materyal Komisyonu').toString();
    final updatedAt = (decoded['updatedAt'] ?? decoded['updated_at'] ?? '').toString();

    final membersRaw = decoded['members'];
    final List membersList = membersRaw is List ? membersRaw : const [];

    final members = membersList
        .whereType<Map>()
        .map((e) => _KomisyonMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return _KomisyonData(
      title: title,
      updatedAt: updatedAt,
      members: members,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materyal Komisyonu'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_KomisyonData>(
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

          if (data.members.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  data.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (data.updatedAt.isNotEmpty)
                  Text('Güncelleme: ${data.updatedAt}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Üye kaydı bulunamadı.'),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                data.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (data.updatedAt.isNotEmpty)
                Text('Güncelleme: ${data.updatedAt}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),

              ...data.members.map(
                    (m) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(m.no.toString())),
                    title: Text(m.adSoyad),
                    subtitle: Text('${m.kurum}\n${m.ilce} • ${m.brans}'),
                    trailing: Text(
                      m.gorev,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KomisyonData {
  final String title;
  final String updatedAt;
  final List<_KomisyonMember> members;

  _KomisyonData({
    required this.title,
    required this.updatedAt,
    required this.members,
  });
}

class _KomisyonMember {
  final int no;
  final String ilce;
  final String adSoyad;
  final String kurum;
  final String unvan;
  final String brans;
  final String gorev;

  _KomisyonMember({
    required this.no,
    required this.ilce,
    required this.adSoyad,
    required this.kurum,
    required this.unvan,
    required this.brans,
    required this.gorev,
  });

  static String _asString(dynamic v) => v == null ? '' : v.toString().trim();

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  factory _KomisyonMember.fromJson(Map<String, dynamic> json) {
    // JSON anahtarları farklı yazılmış olabilir diye toleranslı:
    return _KomisyonMember(
      no: _asInt(json['no'] ?? json['NO'] ?? json['sira'] ?? json['SIRA']),
      ilce: _asString(json['ilce'] ?? json['ILCE']),
      adSoyad: _asString(json['adSoyad'] ?? json['AD_SOYAD'] ?? json['ad_soyad']),
      kurum: _asString(json['kurum'] ?? json['KURUM']),
      unvan: _asString(json['unvan'] ?? json['UNVAN']),
      brans: _asString(json['brans'] ?? json['BRANS']),
      gorev: _asString(json['gorev'] ?? json['GOREV']),
    );
  }
}

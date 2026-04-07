import 'package:flutter/material.dart';

class TasimaliOkulDetailPage extends StatefulWidget {
  final String kategori;
  final String okulAdi;
  final List<Map<String, dynamic>> rows;

  const TasimaliOkulDetailPage({
    super.key,
    required this.kategori,
    required this.okulAdi,
    required this.rows,
  });

  @override
  State<TasimaliOkulDetailPage> createState() => _TasimaliOkulDetailPageState();
}

class _TasimaliOkulDetailPageState extends State<TasimaliOkulDetailPage> {
  String _query = '';

  String _labelize(String key) {
    return key
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _asStr(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  dynamic _pick(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (row.containsKey(k) && row[k] != null) return row[k];
    }
    return null;
  }

  /// Önemli alanlar (önce bunları göster)
  List<MapEntry<String, dynamic>> _primaryEntries(Map<String, dynamic> row) {
    final primaryKeys = <String>[
      'MERKEZ_OKULLAR',
      'ILCE',
      'IL',
      'TASIMA_GUZERGAHI',
      'TASIMA_TURU',
      'OGRENCI_SAYISI',
      'MESAFE_KM',
      'GUNLUK_TASIMA_UCRETI',
      'SOFOR_ADI',
      'ARAC_PLAKA',
      'YUKLENICI',
    ];

    final entries = <MapEntry<String, dynamic>>[];
    for (final k in primaryKeys) {
      if (row.containsKey(k)) entries.add(MapEntry(k, row[k]));
      final lower = k.toLowerCase();
      if (row.containsKey(lower) && !row.containsKey(k)) {
        entries.add(MapEntry(lower, row[lower]));
      }
    }
    // Aynı key tekrarını engelle
    final seen = <String>{};
    return entries.where((e) => seen.add(e.key)).toList();
  }

  /// Diğer alanlar (primary dışındakiler)
  List<MapEntry<String, dynamic>> _secondaryEntries(Map<String, dynamic> row) {
    final primarySet = <String>{
      'MERKEZ_OKULLAR',
      'ILCE',
      'IL',
      'TASIMA_GUZERGAHI',
      'TASIMA_TURU',
      'OGRENCI_SAYISI',
      'MESAFE_KM',
      'GUNLUK_TASIMA_UCRETI',
      'SOFOR_ADI',
      'ARAC_PLAKA',
      'YUKLENICI',
      // lower varyasyonlar da dışarıda kalsın
      'merkez_okullar',
      'ilce',
      'il',
      'tasima_guzergahi',
      'tasima_turu',
      'ogrenci_sayisi',
      'mesafe_km',
      'gunluk_tasima_ucreti',
      'sofor_adi',
      'arac_plaka',
      'yuklenici',
    };

    final entries = row.entries
        .where((e) => !primarySet.contains(e.key))
        .toList();

    entries.sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    // Filtre
    final filtered = widget.rows.where((row) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();

      // satırdaki tüm string değerler içinde ara
      for (final v in row.values) {
        if (v == null) continue;
        final s = v.toString().toLowerCase();
        if (s.contains(q)) return true;
      }
      return false;
    }).toList();

    // Üst istatistikler
    int toplamKayit = filtered.length;

    int toplamOgrenci = 0;
    double toplamKm = 0;
    double toplamGunlukUcret = 0;

    for (final r in filtered) {
      final ogr = _asInt(_pick(r, ['OGRENCI_SAYISI', 'ogrenci_sayisi']));
      final km = _asDouble(_pick(r, ['MESAFE_KM', 'mesafe_km']));
      final ucret = _asDouble(_pick(r, ['GUNLUK_TASIMA_UCRETI', 'gunluk_tasima_ucreti']));

      toplamOgrenci += ogr;
      toplamKm += km;
      toplamGunlukUcret += ucret;
    }

    final ortKm = toplamKayit == 0 ? 0 : (toplamKm / toplamKayit);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.okulAdi),
      ),
      body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ara (güzergah, yerleşim, plaka, yüklenici...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _query = ''),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Özet kartı
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.kategori}\n'
                            'Kayıt: $toplamKayit',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Öğrenci', value: '$toplamOgrenci'),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Ort. Km', value: ortKm.toStringAsFixed(1)),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Günlük ₺', value: toplamGunlukUcret.toStringAsFixed(0)),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Liste
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Kayıt bulunamadı.'))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final row = filtered[i];

                // Özet alanlar
                final guzergah = _asStr(_pick(row, ['TASIMA_GUZERGAHI', 'tasima_guzergahi']));
                final ogr = _asStr(_pick(row, ['OGRENCI_SAYISI', 'ogrenci_sayisi']));
                final km = _asStr(_pick(row, ['MESAFE_KM', 'mesafe_km']));
                final ucret =
                _asStr(_pick(row, ['GUNLUK_TASIMA_UCRETI', 'gunluk_tasima_ucreti']));

                final tasimaTuru = _asStr(_pick(row, ['TASIMA_TURU', 'tasima_turu']));

                final primary = _primaryEntries(row);
                final secondary = _secondaryEntries(row);

                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text(guzergah != '-' ? guzergah : 'Güzergah ${i + 1}'),
                    subtitle: Text(
                      'Tür: $tasimaTuru • Öğrenci: $ogr • Km: $km • Ücret: $ucret',
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            if (primary.isNotEmpty)
                              ...primary.map((e) => _FieldTile(
                                label: _labelize(e.key.toString()),
                                value: _asStr(e.value),
                              )),

                            if (secondary.isNotEmpty) ...[
                              const Divider(height: 12),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Diğer Alanlar',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              ...secondary.map((e) => _FieldTile(
                                label: _labelize(e.key.toString()),
                                value: _asStr(e.value),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ],
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

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;

  const _FieldTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
    );
  }
}

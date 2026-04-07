// lib/core/reports/report_data_service.dart
import 'package:il_mem_yonetim/core/data/json_repository.dart';

class TeacherDistrictRow {
  final String ilce;
  final int norm;
  final int kadrolu;
  final int sozlesmeli;
  final Map<String, int> branchTotals;

  TeacherDistrictRow({
    required this.ilce,
    required this.norm,
    required this.kadrolu,
    required this.sozlesmeli,
    required this.branchTotals,
  });

  int get toplam => kadrolu + sozlesmeli;
}

class SchoolDetailRow {
  final String okulAdi;
  final String ilce;
  final String tur;
  final int norm;
  final int kadrolu;
  final int sozlesmeli;
  final Map<String, int> branchTotals;
  final bool tasimali;

  SchoolDetailRow({
    required this.okulAdi,
    required this.ilce,
    required this.tur,
    required this.norm,
    required this.kadrolu,
    required this.sozlesmeli,
    required this.branchTotals,
    required this.tasimali,
  });

  int get toplam => kadrolu + sozlesmeli;
}

class TransportationAggRow {
  final String ilce;
  final int ozel;
  final int orta;
  final int temel;
  final int merkezOkulSayisi;

  TransportationAggRow({
    required this.ilce,
    required this.ozel,
    required this.orta,
    required this.temel,
    required this.merkezOkulSayisi,
  });

  int get toplam => ozel + orta + temel;
}

class DykAggRow {
  final String ilce;
  final int kursSayisi;
  final int ogrenciSayisi;
  final Map<String, int> dersKurs;

  DykAggRow({
    required this.ilce,
    required this.kursSayisi,
    required this.ogrenciSayisi,
    required this.dersKurs,
  });
}

class DykSchoolRow {
  final String ilce;
  final String okulAdi;
  final int kursSayisi;
  final int ogrenciSayisi;
  final Map<String, int> dersKurs;

  DykSchoolRow({
    required this.ilce,
    required this.okulAdi,
    required this.kursSayisi,
    required this.ogrenciSayisi,
    required this.dersKurs,
  });
}

class ReportDataService {
  static final JsonRepository _repo = JsonRepository();

  // ✅ GitHub paths (baseUrl = .../data)
  static const String okullarPath = 'tunceli_okullar.json';
  static const String dykPath = 'dyk_kurslari.json';
  static const String tasimaliOzelPath = 'tasimali/tasimali_ozel.json';
  static const String tasimaliOrtaPath = 'tasimali/tasimali_orta.json';
  static const String tasimaliTemelPath = 'tasimali/tasimali_temel.json';

  static Future<List<Map<String, dynamic>>> _readJsonRecords(
      String path, {
        bool forceRefresh = false,
      }) async {
    final dynamic decoded = await _repo.getJson(
      path,
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      final rec = map['records'];
      if (rec is List) {
        return rec
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      for (final key in ['data', 'items', 'results', 'list']) {
        final v = map[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      return [map];
    }

    return [];
  }

  // =========================================================
  // ✅ Taşımalı merkez okullar (3 json birleştir)
  // =========================================================
  static Future<Set<String>> loadTasimaliMerkezOkullar({
    bool forceRefresh = false,
  }) async {
    final all = <Map<String, dynamic>>[];
    all.addAll(await _readJsonRecords(tasimaliOzelPath, forceRefresh: forceRefresh));
    all.addAll(await _readJsonRecords(tasimaliOrtaPath, forceRefresh: forceRefresh));
    all.addAll(await _readJsonRecords(tasimaliTemelPath, forceRefresh: forceRefresh));

    final set = <String>{};
    for (final r in all) {
      final raw = (r['MERKEZ_OKULLAR'] ?? '').toString().trim();
      if (raw.isEmpty) continue;

      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        set.add(_normName(t));
      }
    }
    return set;
  }

  // =========================================================
  // ✅ Öğretmen sayısını güvenli hesapla:
  //    1) branşlar doluysa: branş toplamı ESAS
  //    2) branş yoksa: ogretmen_durumu veya flat alanlar
  // =========================================================
  static ({int norm, int kadrolu, int sozlesmeli}) _resolveTeacherCounts(
      Map<String, dynamic> o,
      ) {
    final odRaw = o['ogretmen_durumu'];
    final od = (odRaw is Map) ? Map<String, dynamic>.from(odRaw) : <String, dynamic>{};

    final norm = _asInt(od['norm'] ?? o['norm'] ?? o['NORM']);

    // Branş var mı?
    final branslar = (o['branslar'] is List) ? List.from(o['branslar']) : const [];
    final bKad = _sumBranchKadrolu(o);
    final bSoz = _sumBranchSozlesmeli(o);

    if (branslar.isNotEmpty) {
      // ✅ ESAS: branş toplamları
      return (norm: norm, kadrolu: bKad, sozlesmeli: bSoz);
    }

    // Branş yoksa yedek:
    final kad = _asInt(od['kadrolu'] ?? o['kadrolu'] ?? o['KADROLU']);
    final soz = _asInt(od['sozlesmeli'] ?? o['sozlesmeli'] ?? o['SOZLESMELI']);
    return (norm: norm, kadrolu: kad, sozlesmeli: soz);
  }

  // =========================================================
  // ✅ 1) Öğretmen Dağılımı (İlçe bazlı)
  // =========================================================
  static Future<List<TeacherDistrictRow>> buildTeacherDistributionByDistrict({
    bool forceRefresh = false,
  }) async {
    final okullar = await _readJsonRecords(okullarPath, forceRefresh: forceRefresh);

    final Map<String, int> normByIlce = {};
    final Map<String, int> kadroluByIlce = {};
    final Map<String, int> sozByIlce = {};
    final Map<String, Map<String, int>> branchByIlce = {};

    for (final o in okullar) {
      final ilce = (o['ilce'] ?? o['ILCE'] ?? '-').toString().trim();

      final c = _resolveTeacherCounts(o);

      normByIlce[ilce] = (normByIlce[ilce] ?? 0) + c.norm;
      kadroluByIlce[ilce] = (kadroluByIlce[ilce] ?? 0) + c.kadrolu;
      sozByIlce[ilce] = (sozByIlce[ilce] ?? 0) + c.sozlesmeli;

      // Branş kırılımı (kadrolu + sözleşmeli)
      final branslar = (o['branslar'] is List) ? List.from(o['branslar']) : const [];
      branchByIlce.putIfAbsent(ilce, () => {});

      for (final b in branslar) {
        if (b is! Map) continue;
        final bm = Map<String, dynamic>.from(b);
        final name = (bm['brans'] ?? bm['BRANS'] ?? '-').toString().trim();
        final total = _asInt(bm['kadrolu']) + _asInt(bm['sozlesmeli']);
        if (name.isEmpty || name == '-') continue;
        branchByIlce[ilce]![name] = (branchByIlce[ilce]![name] ?? 0) + total;
      }
    }

    final rows = <TeacherDistrictRow>[];
    for (final ilce in normByIlce.keys) {
      rows.add(
        TeacherDistrictRow(
          ilce: ilce,
          norm: normByIlce[ilce] ?? 0,
          kadrolu: kadroluByIlce[ilce] ?? 0,
          sozlesmeli: sozByIlce[ilce] ?? 0,
          branchTotals: branchByIlce[ilce] ?? {},
        ),
      );
    }

    rows.sort((a, b) => a.ilce.compareTo(b.ilce));
    return rows;
  }

  // =========================================================
  // ✅ 1) Okul Bazlı Detay
  // =========================================================
  static Future<List<SchoolDetailRow>> buildSchoolDetails({
    bool forceRefresh = false,
  }) async {
    final okullar = await _readJsonRecords(okullarPath, forceRefresh: forceRefresh);
    final tasimaliMerkezSet = await loadTasimaliMerkezOkullar(forceRefresh: forceRefresh);

    final out = <SchoolDetailRow>[];

    for (final o in okullar) {
      final okulAdi = (o['okul_adi'] ?? o['OKUL_ADI'] ?? '-').toString().trim();
      final ilce = (o['ilce'] ?? o['ILCE'] ?? '-').toString().trim();

      final c = _resolveTeacherCounts(o);

      final tur = _inferSchoolType(okulAdi);

      final bransTotals = <String, int>{};
      final branslar = (o['branslar'] is List) ? List.from(o['branslar']) : const [];
      for (final b in branslar) {
        if (b is! Map) continue;
        final bm = Map<String, dynamic>.from(b);
        final name = (bm['brans'] ?? bm['BRANS'] ?? '-').toString().trim();
        final total = _asInt(bm['kadrolu']) + _asInt(bm['sozlesmeli']);
        if (name.isEmpty || name == '-') continue;
        bransTotals[name] = (bransTotals[name] ?? 0) + total;
      }

      final tasimali = tasimaliMerkezSet.contains(_normName(okulAdi));

      out.add(
        SchoolDetailRow(
          okulAdi: okulAdi,
          ilce: ilce,
          tur: tur,
          norm: c.norm,
          kadrolu: c.kadrolu,
          sozlesmeli: c.sozlesmeli,
          branchTotals: bransTotals,
          tasimali: tasimali,
        ),
      );
    }

    out.sort((a, b) => a.ilce.compareTo(b.ilce));
    return out;
  }

  // =========================================================
  // ✅ 2) Taşımalı Eğitim (İlçe bazlı öğrenci + merkez okul sayısı)
  // =========================================================
  static Future<List<TransportationAggRow>> buildTransportationAgg({
    bool forceRefresh = false,
  }) async {
    final ozel = await _readJsonRecords(tasimaliOzelPath, forceRefresh: forceRefresh);
    final orta = await _readJsonRecords(tasimaliOrtaPath, forceRefresh: forceRefresh);
    final temel = await _readJsonRecords(tasimaliTemelPath, forceRefresh: forceRefresh);

    final Map<String, int> ozelBy = {};
    final Map<String, int> ortaBy = {};
    final Map<String, int> temelBy = {};
    final Map<String, Set<String>> merkezOkullarBy = {};

    void addRows(List<Map<String, dynamic>> rows, Map<String, int> targetMap) {
      for (final r in rows) {
        final ilce = _extractIlceFromGuzergah((r['TASIMA_GUZERGAHI'] ?? '').toString());
        final ogr = _asInt(r['OGRENCI_SAYISI']);
        targetMap[ilce] = (targetMap[ilce] ?? 0) + ogr;

        final merkez = (r['MERKEZ_OKULLAR'] ?? '').toString().trim();
        if (merkez.isNotEmpty) {
          merkezOkullarBy.putIfAbsent(ilce, () => <String>{});
          for (final line in merkez.split('\n')) {
            final t = line.trim();
            if (t.isEmpty) continue;
            merkezOkullarBy[ilce]!.add(_normName(t));
          }
        }
      }
    }

    addRows(ozel, ozelBy);
    addRows(orta, ortaBy);
    addRows(temel, temelBy);

    final allIlceler = <String>{...ozelBy.keys, ...ortaBy.keys, ...temelBy.keys};

    final out = <TransportationAggRow>[];
    for (final ilce in allIlceler) {
      out.add(
        TransportationAggRow(
          ilce: ilce,
          ozel: ozelBy[ilce] ?? 0,
          orta: ortaBy[ilce] ?? 0,
          temel: temelBy[ilce] ?? 0,
          merkezOkulSayisi: (merkezOkullarBy[ilce] ?? {}).length,
        ),
      );
    }

    out.sort((a, b) => a.ilce.compareTo(b.ilce));
    return out;
  }

  // =========================================================
  // ✅ 3) DYK (İlçe bazlı)
  // =========================================================
  static Future<List<DykAggRow>> buildDykAgg({bool forceRefresh = false}) async {
    final rows = await _readJsonRecords(dykPath, forceRefresh: forceRefresh);

    final Map<String, int> kursBy = {};
    final Map<String, int> ogrBy = {};
    final Map<String, Map<String, int>> dersByIlce = {};

    for (final r in rows) {
      final ilce = (r['ILCE_ADI'] ?? '-').toString().trim();
      final ders = (r['DERS_ADI'] ?? '-').toString().trim();

      final kurs = _asInt(r['KURS_SAYISI']);
      final ogr = _asInt(r['TOPLAM']);

      kursBy[ilce] = (kursBy[ilce] ?? 0) + kurs;
      ogrBy[ilce] = (ogrBy[ilce] ?? 0) + ogr;

      dersByIlce.putIfAbsent(ilce, () => {});
      dersByIlce[ilce]![ders] = (dersByIlce[ilce]![ders] ?? 0) + kurs;
    }

    final out = <DykAggRow>[];
    for (final ilce in kursBy.keys) {
      out.add(
        DykAggRow(
          ilce: ilce,
          kursSayisi: kursBy[ilce] ?? 0,
          ogrenciSayisi: ogrBy[ilce] ?? 0,
          dersKurs: dersByIlce[ilce] ?? {},
        ),
      );
    }

    out.sort((a, b) => a.ilce.compareTo(b.ilce));
    return out;
  }

  // =========================================================
  // ✅ 3) DYK (Okul bazlı)
  // =========================================================
  static Future<List<DykSchoolRow>> buildDykSchools({bool forceRefresh = false}) async {
    final rows = await _readJsonRecords(dykPath, forceRefresh: forceRefresh);

    final Map<String, int> kursByKey = {};
    final Map<String, int> ogrByKey = {};
    final Map<String, Map<String, int>> dersByKey = {};

    for (final r in rows) {
      final ilce = (r['ILCE_ADI'] ?? '-').toString().trim();
      final okul = (r['KURUM_ADI'] ?? '-').toString().trim();
      final ders = (r['DERS_ADI'] ?? '-').toString().trim();

      final kurs = _asInt(r['KURS_SAYISI']);
      final ogr = _asInt(r['TOPLAM']);

      final key = '$ilce||$okul';

      kursByKey[key] = (kursByKey[key] ?? 0) + kurs;
      ogrByKey[key] = (ogrByKey[key] ?? 0) + ogr;

      dersByKey.putIfAbsent(key, () => {});
      dersByKey[key]![ders] = (dersByKey[key]![ders] ?? 0) + kurs;
    }

    final out = <DykSchoolRow>[];
    for (final key in kursByKey.keys) {
      final parts = key.split('||');
      final ilce = parts.isNotEmpty ? parts[0] : '-';
      final okul = parts.length > 1 ? parts[1] : '-';

      out.add(
        DykSchoolRow(
          ilce: ilce,
          okulAdi: okul,
          kursSayisi: kursByKey[key] ?? 0,
          ogrenciSayisi: ogrByKey[key] ?? 0,
          dersKurs: dersByKey[key] ?? {},
        ),
      );
    }

    out.sort((a, b) {
      final c = a.ilce.compareTo(b.ilce);
      if (c != 0) return c;
      return a.okulAdi.compareTo(b.okulAdi);
    });

    return out;
  }

  // =========================================================
  // helpers
  // =========================================================
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    return int.tryParse(s) ?? 0;
  }

  static int _sumBranchKadrolu(Map<String, dynamic> okul) {
    final branslar = (okul['branslar'] is List) ? List.from(okul['branslar']) : const [];
    int sum = 0;
    for (final b in branslar) {
      if (b is! Map) continue;
      final bm = Map<String, dynamic>.from(b);
      sum += _asInt(bm['kadrolu'] ?? bm['KADROLU']);
    }
    return sum;
  }

  static int _sumBranchSozlesmeli(Map<String, dynamic> okul) {
    final branslar = (okul['branslar'] is List) ? List.from(okul['branslar']) : const [];
    int sum = 0;
    for (final b in branslar) {
      if (b is! Map) continue;
      final bm = Map<String, dynamic>.from(b);
      sum += _asInt(bm['sozlesmeli'] ?? bm['SOZLESMELI']);
    }
    return sum;
  }

  static String _extractIlceFromGuzergah(String guzergah) {
    final parts = guzergah
        .split(' - ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return _titleCaseTr(parts[1]);
    return '-';
  }

  static String _inferSchoolType(String okulAdi) {
    final s = okulAdi.toLowerCase();
    if (s.contains('fen lisesi')) return 'Fen Lisesi';
    if (s.contains('ilkokul')) return 'İlkokul';
    if (s.contains('ortaokul')) return 'Ortaokul';
    if (s.contains('anaokul') || s.contains('anasinif')) return 'Anaokulu';
    if (s.contains('mesleki') || s.contains('mtal')) return 'MTAL';
    if (s.contains('imam hatip')) return 'İHL';
    if (s.contains('anadolu lisesi')) return 'Anadolu Lisesi';
    if (s.contains('lisesi')) return 'Lise';
    return 'Diğer';
  }

  static String _normName(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String _titleCaseTr(String s) {
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

class BransDurumu {
  final String brans;
  final int? norm;
  final int? kadrolu;
  final int? sozlesmeli;

  const BransDurumu({
    required this.brans,
    required this.norm,
    required this.kadrolu,
    required this.sozlesmeli,
  });

  int get toplam => (kadrolu ?? 0) + (sozlesmeli ?? 0);
  int get fark => (norm ?? 0) - toplam;

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static String _asString(dynamic v) => v == null ? '' : v.toString().trim();

  factory BransDurumu.fromJson(Map<String, dynamic> json) {
    return BransDurumu(
      brans: _asString(json['brans'] ?? json['BRANS']),
      norm: _toInt(json['norm'] ?? json['NORM']),
      kadrolu: _toInt(json['kadrolu'] ?? json['KADROLU']),
      sozlesmeli: _toInt(json['sozlesmeli'] ?? json['SOZLESMELI']),
    );
  }
}

class School {
  final String il;
  final String ilce;
  final String okulAdi;
  final String kurumKodu;

  final int? norm;
  final int? kadrolu;
  final int? sozlesmeli;

  final double? latitude;
  final double? longitude;

  /// ✅ Branş bazlı liste (yoksa boş gelir)
  final List<BransDurumu> branslar;

  const School({
    required this.il,
    required this.ilce,
    required this.okulAdi,
    required this.kurumKodu,
    required this.norm,
    required this.kadrolu,
    required this.sozlesmeli,
    required this.latitude,
    required this.longitude,
    required this.branslar,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String _asString(dynamic v) => v == null ? '' : v.toString().trim();

  /// Map içinden farklı yazımları dene (lower/UPPER)
  static dynamic _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return null;
  }

  factory School.fromJson(Map<String, dynamic> json) {
    // 1) İl / İlçe / Okul / Kurum kodu (lower + UPPER)
    final il = _asString(_pick(json, ['il', 'IL']));
    final ilce = _asString(_pick(json, ['ilce', 'ILCE', 'ILCE_ADI']));
    final okulAdi = _asString(_pick(json, ['okul_adi', 'OKUL_ADI']));
    final kurumKodu = _asString(_pick(json, ['kurum_kodu', 'KURUM_KODU']));

    // 2) Öğretmen durumu: nested (ogretmen_durumu / OGRETMEN_DURUMU) varsa onu kullan,
    // yoksa flat alanlardan dene.
    final ogRaw = _pick(json, ['ogretmen_durumu', 'OGRETMEN_DURUMU']);
    final og = (ogRaw is Map) ? ogRaw.cast<String, dynamic>() : <String, dynamic>{};

    final norm = _toInt(_pick(og, ['norm', 'NORM']) ?? _pick(json, ['norm', 'NORM']));
    final kadrolu = _toInt(_pick(og, ['kadrolu', 'KADROLU']) ?? _pick(json, ['kadrolu', 'KADROLU']));
    final sozlesmeli =
    _toInt(_pick(og, ['sozlesmeli', 'SOZLESMELI']) ?? _pick(json, ['sozlesmeli', 'SOZLESMELI']));

    // 3) Konum: nested (konum) varsa onu kullan, yoksa flat alanlardan dene.
    final konumRaw = _pick(json, ['konum', 'KONUM']);
    final konum = (konumRaw is Map) ? konumRaw.cast<String, dynamic>() : <String, dynamic>{};

    final lat = _toDouble(
      _pick(konum, ['latitude', 'LATITUDE', 'lat', 'LAT']) ??
          _pick(json, ['latitude', 'LATITUDE', 'lat', 'LAT']),
    );

    final lng = _toDouble(
      _pick(konum, ['longitude', 'LONGITUDE', 'lng', 'LNG', 'lon', 'LON']) ??
          _pick(json, ['longitude', 'LONGITUDE', 'lng', 'LNG', 'lon', 'LON']),
    );

    // 4) Branş listesi: branslar / BRANSLAR
    final bransRaw = _pick(json, ['branslar', 'BRANSLAR']);
    final bransList = (bransRaw is List)
        ? bransRaw
        .whereType<Map>()
        .map((e) => BransDurumu.fromJson(e.cast<String, dynamic>()))
        .toList()
        : const <BransDurumu>[];

    return School(
      il: il,
      ilce: ilce,
      okulAdi: okulAdi,
      kurumKodu: kurumKodu,
      norm: norm,
      kadrolu: kadrolu,
      sozlesmeli: sozlesmeli,
      latitude: lat,
      longitude: lng,
      branslar: bransList,
    );
  }

  int get toplamOgretmen => (kadrolu ?? 0) + (sozlesmeli ?? 0);

  /// norm - mevcut; >0 açık, 0 dolu, <0 fazla
  int get normFarki => (norm ?? 0) - toplamOgretmen;
}

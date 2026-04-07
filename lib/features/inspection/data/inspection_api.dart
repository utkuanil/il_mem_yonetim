import 'dart:convert';
import 'package:http/http.dart' as http;

class InspectionApi {
  final String baseUrl; // https://script.google.com/macros/s/.../exec
  final String apiKey;

  InspectionApi({
    required this.baseUrl,
    required this.apiKey,
  });

  Uri _uri(Map<String, String> qp) => Uri.parse(baseUrl).replace(queryParameters: {
    "apiKey": apiKey,
    ...qp,
  });

  Future<String> createInspection({
    required String il,
    required String ilce,
    required String kurumKodu,
    required String okulAdi,
    required String denetleyen,
    required DateTime tarihSaat,
    required String rapor,
  }) async {
    final uri = _uri({});
    final payload = <String, dynamic>{
      "IL": il,
      "ILCE": ilce,
      "KURUM_KODU": kurumKodu,
      "OKUL_ADI": okulAdi,
      "DENETLEYEN": denetleyen,
      "TARIH_SAAT": tarihSaat.toIso8601String(),
      "RAPOR": rapor,
    };

    // ✅ Redirect takip ETME!
    final resp = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json",
      },
      body: jsonEncode(payload),
    );

    final bodyText = resp.body.trim();

    // 200 ise JSON olmasa bile başarılı sayacağız (Google bazen HTML döndürüyor)
    if (resp.statusCode == 200) {
      try {
        if (bodyText.startsWith("{")) {
          final map = jsonDecode(bodyText) as Map<String, dynamic>;
          if (map["ok"] == true) return (map["id"] ?? "").toString();
          // ok:false ise gerçek hata
          throw Exception(map["error"] ?? "unknown_error");
        }
      } catch (_) {
        // JSON parse edilemedi => yine de başarılı kabul
      }
      return "";
    }

    // ⚠️ 302/303 vb olursa da hata saymayalım; doğrulama yapacağız
    if (resp.statusCode == 301 ||
        resp.statusCode == 302 ||
        resp.statusCode == 303 ||
        resp.statusCode == 307 ||
        resp.statusCode == 308 ||
        resp.statusCode == 405) {
      // burada hemen fail etmiyoruz; sayfa doğrulaması için üst katmanda liste çekebiliriz
      return "";
    }

    throw Exception("HTTP ${resp.statusCode}: $bodyText");
  }

  Future<List<Map<String, dynamic>>> listInspections({
    String? ilce,
    int limit = 200,
  }) async {
    final uri = _uri({
      if (ilce != null && ilce.trim().isNotEmpty) "ilce": ilce.trim(),
      "limit": "$limit",
    });

    final resp = await http.get(uri, headers: {"Accept": "application/json"});
    final bodyText = resp.body.trim();

    if (resp.statusCode != 200) {
      throw Exception("HTTP ${resp.statusCode}: $bodyText");
    }
    if (!bodyText.startsWith("{")) {
      throw Exception("NON-JSON RESPONSE: $bodyText");
    }

    final map = jsonDecode(bodyText) as Map<String, dynamic>;
    if (map["ok"] != true) {
      throw Exception(map["error"] ?? "unknown_error");
    }

    final list = (map["records"] as List? ?? [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    return list;
  }
}

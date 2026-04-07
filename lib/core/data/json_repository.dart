import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class JsonRepository {
  static const String baseUrl =
      'https://raw.githubusercontent.com/utkuanil/il-mem-veri/main/data';

  /// JSON döner (Map veya List)
  /// - forceRefresh=false: cache varsa hemen cache döner, arkada günceller
  /// - forceRefresh=true : cache'i bypass eder, remote'tan anında çeker ve cache'e yazar
  Future<dynamic> getJson(
      String path, {
        bool forceRefresh = false,
        bool cacheBust = false,
      }) async {
    final file = await _localFile(path);

    // 1) Cache varsa ve forceRefresh değilse cache'i döndür
    if (!forceRefresh && await file.exists()) {
      final cached = await file.readAsString();
      // Arkadan güncelle (UI tetiklenmez)
      _refreshInBackground(path, file, cacheBust: cacheBust);
      return jsonDecode(cached);
    }

    // 2) Remote çek (forceRefresh veya cache yok)
    final remoteText = await _fetchRemote(path, cacheBust: cacheBust);
    await file.writeAsString(remoteText);
    return jsonDecode(remoteText);
  }

  /// Geriye dönük uyumluluk
  Future<dynamic> fetchJson(String path) => getJson(path);

  /// Belirli bir dosyanın cache'ini siler (debug / reset için faydalı)
  Future<void> clearCache(String path) async {
    final file = await _localFile(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Tüm json_cache klasörünü siler (tam reset)
  Future<void> clearAllCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/json_cache');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  Future<void> _refreshInBackground(
      String path,
      File file, {
        bool cacheBust = false,
      }) async {
    try {
      final remoteText = await _fetchRemote(path, cacheBust: cacheBust);
      final oldText = await file.readAsString();

      if (remoteText != oldText) {
        await file.writeAsString(remoteText);
      }
    } catch (_) {
      // sessiz geç
    }
  }

  Future<String> _fetchRemote(
      String path, {
        bool cacheBust = false,
      }) async {
    // Cache bust: her çağrıda URL farklı olsun
    final v = DateTime.now().millisecondsSinceEpoch;
    final url = cacheBust
        ? Uri.parse('$baseUrl/$path?v=$v')
        : Uri.parse('$baseUrl/$path');

    final resp = await http.get(
      url,
      headers: const {
        // Bazı istemciler/katmanlar için yardımcı olur
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('GitHub JSON alınamadı: $path (${resp.statusCode})');
    }

    return resp.body;
  }

  Future<File> _localFile(String path) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/json_cache/$path');
    await file.parent.create(recursive: true);
    return file;
  }
}

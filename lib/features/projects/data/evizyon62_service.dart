import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../models/evizyon62_application.dart';

class Evizyon62Service {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/utkuanil/il-mem-veri/main/data';
  static const String _configPath = 'evizyon62_sources.json';

  Future<List<_SheetSource>> _fetchSources() async {
    final url = Uri.parse('$_baseUrl/$_configPath');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        'E-Vizyon 62 kaynak listesi alınamadı (HTTP ${res.statusCode}).',
      );
    }

    final decoded = json.decode(utf8.decode(res.bodyBytes));

    if (decoded is! List) {
      throw Exception('evizyon62_sources.json beklenen formatta değil.');
    }

    return decoded
        .whereType<Map>()
        .map((e) => _SheetSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Uri _buildCsvUri({
    required String sheetId,
    String? gid,
  }) {
    if (gid != null && gid.trim().isNotEmpty) {
      return Uri.parse(
        'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv&gid=$gid',
      );
    }

    return Uri.parse(
      'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv',
    );
  }

  Future<List<Evizyon62Application>> fetchAllApplications() async {
    final sources = await _fetchSources();
    final all = <Evizyon62Application>[];

    for (final source in sources) {
      final items = await _fetchFromSource(source);
      all.addAll(items);
    }

    all.sort((a, b) {
      final y = a.year.compareTo(b.year);
      if (y != 0) return y;
      final m = a.month.compareTo(b.month);
      if (m != 0) return m;
      return a.activityName.compareTo(b.activityName);
    });

    return all;
  }

  Future<List<Evizyon62Application>> fetchApplications({
    int? year,
    int? month,
  }) async {
    final all = await fetchAllApplications();

    return all.where((e) {
      final yearOk = year == null ? true : e.year == year;
      final monthOk = month == null || month == 0 ? true : e.month == month;
      return yearOk && monthOk;
    }).toList();
  }

  Future<List<Evizyon62Application>> _fetchFromSource(
      _SheetSource source,
      ) async {
    final uri = _buildCsvUri(
      sheetId: source.sheetId,
      gid: source.gid,
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
        '${source.year} ${source.monthLabel} verisi alınamadı '
            '(HTTP ${res.statusCode}).',
      );
    }

    final csvText = utf8.decode(res.bodyBytes);
    final rows = const CsvToListConverter(eol: '\n').convert(csvText);

    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();

    int findHeaderIndex(
        List<String> containsAny, {
          bool required = true,
        }) {
      final idx = headers.indexWhere((header) {
        final normalizedHeader = _normalize(header);
        return containsAny.any(
              (key) => normalizedHeader.contains(_normalize(key)),
        );
      });

      if (idx == -1 && required) {
        throw Exception(
          '${source.year} ${source.monthLabel} için gerekli sütun bulunamadı: '
              '${containsAny.join(' | ')}',
        );
      }

      return idx;
    }

    final iFullName = findHeaderIndex([
      'ad ve soyad',
      'adı soyadı',
      'ad soyad',
      'başvuran kişinin adı soyadı',
      'basvuran kisinin adi soyadi',
      'adınız soyadınız',
    ]);

    final iTitle = findHeaderIndex([
      'unvan',
      'ünvan',
      'görevi',
      'gorevi',
      'title',
    ], required: false);

    final iDistrict = findHeaderIndex([
      'ilçe',
      'ilcesi',
      'ilçesi',
      'ilce',
      'district',
    ], required: false);

    final iSchool = findHeaderIndex([
      'okul',
      'kurum',
      'okulu/kurumu',
      'okulu kurumu',
      'okul / kurum',
      'okulu',
    ], required: false);

    final iThematic = findHeaderIndex([
      'tematik alan',
      'etkinliğin tematik alanı',
      'etkinligin tematik alani',
      'thematic',
    ], required: false);

    final iActivityName = findHeaderIndex([
      'etkinliğin adı',
      'etkinligin adi',
      'etkinlik adı',
      'etkinlik adi',
      'proje adı',
      'proje adi',
      'faaliyet adı',
      'faaliyet adi',
    ]);

    final iPurpose = findHeaderIndex([
      'amacını bir cümle',
      'amacini bir cumle',
      'amacı',
      'amaci',
      'amaç',
      'purpose',
    ], required: false);

    final iParticipants = findHeaderIndex([
      'katılımcı say',
      'katilimci say',
      'katılımcı',
      'katilimci',
      'katılımcı sayısı',
      'katilimci sayisi',
    ], required: false);

    final iBudget = findHeaderIndex([
      'bütçe',
      'butce',
      'etkinlik bütç',
      'etkinlik butce',
      'maliyet',
      'budget',
    ], required: false);

    String cell(List row, int index) {
      if (index < 0 || index >= row.length) return '';
      return row[index].toString().trim();
    }

    final list = <Evizyon62Application>[];

    for (final r in rows.skip(1)) {
      final fullName = cell(r, iFullName);
      final activityName = cell(r, iActivityName);

      if (fullName.isEmpty && activityName.isEmpty) continue;

      list.add(
        Evizyon62Application(
          fullName: fullName,
          title: cell(r, iTitle),
          district: cell(r, iDistrict),
          school: cell(r, iSchool),
          thematicArea: cell(r, iThematic),
          activityName: activityName,
          purposeOneSentence: cell(r, iPurpose),
          participantsText: cell(r, iParticipants),
          budgetText: cell(r, iBudget),
          year: source.year,
          month: source.month,
          monthLabel: source.monthLabel,
          sourceKey: source.sourceKey,
        ),
      );
    }

    return list;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _SheetSource {
  final int year;
  final int month;
  final String monthLabel;
  final String sheetId;
  final String? gid;
  final String sourceKey;

  const _SheetSource({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.sheetId,
    this.gid,
    required this.sourceKey,
  });

  factory _SheetSource.fromJson(Map<String, dynamic> json) {
    final year = (json['year'] as num).toInt();
    final month = (json['month'] as num).toInt();

    return _SheetSource(
      year: year,
      month: month,
      monthLabel: json['monthLabel']?.toString() ?? 'Tümü',
      sheetId: json['sheetId']?.toString() ?? '',
      gid: json['gid']?.toString(),
      sourceKey: json['sourceKey']?.toString() ?? '${year}_$month',
    );
  }
}
import '../models/evizyon62_application.dart';

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;



class Evizyon62Service {
  static const _sheetId = "159ak1MUNLI22ibGqdjUPPw26TPjgap0TwucQ9GapQHY";
  static const _gid = "335448382";

  static Uri get _csvUri => Uri.parse(
    "https://docs.google.com/spreadsheets/d/$_sheetId/gviz/tq?tqx=out:csv&gid=$_gid",
  );

  Future<List<Evizyon62Application>> fetchApplications() async {
    final res = await http.get(_csvUri);

    if (res.statusCode != 200) {
      throw Exception(
        "E-Vizyon 62 verisi alınamadı (HTTP ${res.statusCode}). "
            "Sheet paylaşımı 'linke sahip olanlar görüntüleyebilir' olmalı.",
      );
    }

    // Güvenli decode
    final csvText = utf8.decode(res.bodyBytes);

    // CSV -> satırlar
    final rows = const CsvToListConverter(eol: '\n').convert(csvText);
    if (rows.isEmpty) return [];

    // Başlık satırı
    final headers = rows.first
        .map((e) => e.toString().trim())
        .toList();

    // Başlık bulma: birden fazla olası eşleşmeyi destekler (Google Forms başlıkları bazen değişebilir)
    int findHeaderIndex(List<String> containsAny) {
      final i = headers.indexWhere((h) {
        final low = h.toLowerCase();
        return containsAny.any((k) => low.contains(k.toLowerCase()));
      });
      if (i == -1) {
        throw Exception("Gerekli sütun bulunamadı: ${containsAny.join(' | ')}");
      }
      return i;
    }

    // Bu anahtarlar Forms başlıklarındaki yaygın ifadeleri yakalar
    final iFullName = findHeaderIndex(["ad ve soyad", "adı soyadı", "ad soyad"]);
    final iTitle = findHeaderIndex(["unvan", "ünvan"]);
    final iDistrict = findHeaderIndex(["ilçe", "ilcen"]);
    final iSchool = findHeaderIndex(["okul", "kurum", "okul / kurum"]);
    final iThematic = findHeaderIndex(["tematik alan"]);
    final iActivityName = findHeaderIndex(["etkinliğin adı", "etkinlik adı"]);
    final iPurpose = findHeaderIndex(["amacını bir cümle", "amaci", "amacını"]);
    final iParticipants = findHeaderIndex(["katılımcı say", "katilimci say"]);
    final iBudget = findHeaderIndex(["bütçe", "butce", "etkinlik bütç"]);

    String cell(List row, int i) =>
        (i < row.length ? row[i] : "").toString().trim();

    final dataRows = rows.skip(1); // başlığı atla

    final list = <Evizyon62Application>[];
    for (final r in dataRows) {
      // boş satırları atlamak için basit kontrol
      final name = cell(r, iFullName);
      final activity = cell(r, iActivityName);

      if (name.isEmpty && activity.isEmpty) continue;

      list.add(
        Evizyon62Application(
          fullName: name,
          title: cell(r, iTitle),
          district: cell(r, iDistrict),
          school: cell(r, iSchool),
          thematicArea: cell(r, iThematic),
          activityName: activity,
          purposeOneSentence: cell(r, iPurpose),
          participantsText: cell(r, iParticipants),
          budgetText: cell(r, iBudget),
        ),
      );
    }

    return list;
  }
}

import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/announcement.dart';

class AnnouncementsRepository {
  const AnnouncementsRepository();

  static const _rssUrl =
      'https://tunceli.meb.gov.tr/meb_iys_dosyalar/xml/rss_duyurular.xml';

  Future<List<Announcement>> fetchAnnouncements() async {
    final res = await http.get(
      Uri.parse(_rssUrl),
      headers: const {
        'User-Agent': 'il_mem_yonetim_app/1.0',
        'Accept': 'application/rss+xml, application/xml;q=0.9, */*;q=0.8',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('RSS alınamadı. Status: ${res.statusCode}');
    }

    final xmlText = _decodeTurkish(res);
    final doc = XmlDocument.parse(xmlText);

    final items = doc.findAllElements('item');

    // underscore uyarısını istemiyorsan _ koyma:
    String textOf(XmlElement e, String name) =>
        e.getElement(name)?.innerText.trim() ?? '';

    return items.map((it) {
      final title = textOf(it, 'title');
      final link = textOf(it, 'link');
      final pubDateStr = textOf(it, 'pubDate');
      final desc = it.getElement('description')?.innerText.trim();

      return Announcement(
        title: title,
        link: link,
        pubDate: _tryParseDate(pubDateStr),
        description: (desc == null || desc.isEmpty) ? null : desc,
      );
    }).toList();
  }

  /// RSS yanıtını doğru charset ile decode eder (TR sitelerinde sık görülen 1254/8859-9).
  String _decodeTurkish(http.Response res) {
    final bytes = res.bodyBytes;

    // 1) Sunucu charset verdiyse onu dene
    final ct = res.headers['content-type'] ?? '';
    final match =
    RegExp(r'charset=([^\s;]+)', caseSensitive: false).firstMatch(ct);
    final charsetName = match?.group(1)?.toLowerCase();

    if (charsetName != null && charsetName.isNotEmpty) {
      final cs = Charset.getByName(charsetName);
      if (cs != null) {
        try {
          return cs.decode(bytes);
        } catch (_) {
          // devam
        }
      }
    }

    // 2) TR'de sık görülen charset'leri sırayla dene
    for (final name in const ['windows-1254', 'iso-8859-9', 'latin5']) {
      final cs = Charset.getByName(name);
      if (cs == null) continue;

      try {
        final s = cs.decode(bytes);
        // Hızlı bozulma kontrolü (Ã veya � varsa muhtemelen yanlış decode)
        if (!s.contains('Ã') && !s.contains('�')) return s;
      } catch (_) {
        // devam
      }
    }

    // 3) Son çare UTF-8
    return const Utf8Codec(allowMalformed: true).decode(bytes);
  }

  DateTime? _tryParseDate(String? s) {
    if (s == null) return null;
    final v = s.trim();
    if (v.isEmpty) return null;

    final iso = DateTime.tryParse(v);
    if (iso != null) return iso;

    return _parseRfc822(v);
  }

  DateTime? _parseRfc822(String v) {
    try {
      final cleaned = v.replaceAll(',', '');
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length < 6) return null;

      final day = int.parse(parts[1]);
      final monStr = parts[2];
      final year = int.parse(parts[3]);

      final timeParts = parts[4].split(':');
      final hh = int.parse(timeParts[0]);
      final mm = int.parse(timeParts[1]);
      final ss = int.parse(timeParts[2]);

      final tz = parts[5]; // +0300 / +0000
      final sign = tz.startsWith('-') ? -1 : 1;
      final tzh = int.parse(tz.substring(1, 3));
      final tzm = int.parse(tz.substring(3, 5));
      final offset = Duration(hours: tzh, minutes: tzm) * sign;

      final month = _monthNumber(monStr);
      if (month == null) return null;

      final utc = DateTime.utc(year, month, day, hh, mm, ss);
      return utc.subtract(offset);
    } catch (_) {
      return null;
    }
  }

  int? _monthNumber(String mon) {
    switch (mon.toLowerCase()) {
      case 'jan':
        return 1;
      case 'feb':
        return 2;
      case 'mar':
        return 3;
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'jun':
        return 6;
      case 'jul':
        return 7;
      case 'aug':
        return 8;
      case 'sep':
        return 9;
      case 'oct':
        return 10;
      case 'nov':
        return 11;
      case 'dec':
        return 12;
      default:
        return null;
    }
  }
}

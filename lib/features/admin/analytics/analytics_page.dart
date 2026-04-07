// lib/features/admin/analytics/analytics_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ✅ GitHub JSON cache repo
import 'package:il_mem_yonetim/core/data/json_repository.dart';

// E-Vizyon (Google Sheets)
import 'package:il_mem_yonetim/features/projects/data/evizyon62_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final repo = JsonRepository();

  // ✅ GitHub paths (JsonRepository.baseUrl zaten .../data)
  static const _schoolsPath = 'tunceli_okullar.json';
  static const _dykPath = 'dyk_kurslari.json';

  bool _loading = true;
  String? _error;

  // Öğretmen analizleri
  late Map<String, int> _branchTotals;
  late int _totalNorm;
  late int _totalKadrolu;
  late int _totalSozlesmeli;

  // İlçe karşılaştırmaları
  late Map<String, int> _schoolCountByDistrict;
  late Map<String, int> _teacherCountByDistrict;

  // DYK
  late Map<String, int> _dykCoursesByLesson;
  late Map<String, int> _dykStudentsByLesson;

  // E-Vizyon
  late int _evizyonTotal;
  late Map<String, int> _evizyonByDistrict;
  late Map<String, int> _evizyonBySchoolType;

  bool _showTeacherCount = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool forceRefresh = false}) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // -------------------------
      // 1) OKULLAR (GitHub)
      // -------------------------
      final schools = await _readJsonListFromRepo(
        _schoolsPath,
        forceRefresh: forceRefresh,
      );

      final branchTotals = <String, int>{};
      int totalNorm = 0, totalKad = 0, totalSoz = 0;

      final schoolCountByDistrict = <String, int>{};
      final teacherCountByDistrict = <String, int>{};

      for (final s in schools) {
        final ilce = (s['ilce'] ?? '-').toString().trim();
        schoolCountByDistrict[ilce] = (schoolCountByDistrict[ilce] ?? 0) + 1;

        final od = (s['ogretmen_durumu'] is Map)
            ? Map<String, dynamic>.from(s['ogretmen_durumu'])
            : <String, dynamic>{};

        final norm = _asInt(od['norm']);
        final kad = _asInt(od['kadrolu']);
        final soz = _asInt(od['sozlesmeli']);

// ✅ Branşlardan say (senin güncelleme yaptığın yer burası)
        final bKad = _sumBranchKadrolu(s);
        final bSoz = _sumBranchSozlesmeli(s);

// ✅ ogretmen_durumu 0 ise branştan fallback
        final kadFinal = (kad == 0 && bKad > 0) ? bKad : kad;
        final sozFinal = (soz == 0 && bSoz > 0) ? bSoz : soz;

        totalNorm += norm;
        totalKad += kadFinal;
        totalSoz += sozFinal;

        teacherCountByDistrict[ilce] =
            (teacherCountByDistrict[ilce] ?? 0) + (kadFinal + sozFinal);


        final branslar =
        (s['branslar'] is List) ? List.from(s['branslar']) : const [];
        for (final b in branslar) {
          if (b is! Map) continue;
          final bm = Map<String, dynamic>.from(b);
          final name = (bm['brans'] ?? '-').toString().trim();
          final total = _asInt(bm['kadrolu']) + _asInt(bm['sozlesmeli']);
          if (name.isEmpty || name == '-') continue;
          branchTotals[name] = (branchTotals[name] ?? 0) + total;
        }
      }

      // -------------------------
      // 2) DYK (GitHub) - records kökü destekli
      // -------------------------
      final dyk = await _readJsonListFromRepo(
        _dykPath,
        forceRefresh: forceRefresh,
      );

      final dykCoursesByLesson = <String, int>{};
      final dykStudentsByLesson = <String, int>{};

      for (final r in dyk) {
        final ders = (r['DERS_ADI'] ?? r['ders'] ?? r['ders_adi'] ?? '-')
            .toString()
            .trim();
        if (ders.isEmpty || ders == '-') continue;

        final kurs = _asInt(r['KURS_SAYISI'] ?? r['kurs_sayisi'] ?? r['kurs']);
        final ogr = _asInt(r['TOPLAM'] ?? r['toplam'] ?? r['ogrenci']);

        dykCoursesByLesson[ders] = (dykCoursesByLesson[ders] ?? 0) + kurs;
        dykStudentsByLesson[ders] = (dykStudentsByLesson[ders] ?? 0) + ogr;
      }

      // -------------------------
      // 3) E-VİZYON (Sheets)
      // -------------------------
      final evizyonService = Evizyon62Service();
      final apps = await evizyonService.fetchApplications();

      final evizyonByDistrict = <String, int>{};
      final evizyonBySchoolType = <String, int>{};

      for (final a in apps) {
        final d = _normalizeDistrict(a.district);
        evizyonByDistrict[d] = (evizyonByDistrict[d] ?? 0) + 1;

        final rawType = _inferSchoolTypeFromName(a.school);
        final type = _normalizeSchoolType(rawType);
        evizyonBySchoolType[type] = (evizyonBySchoolType[type] ?? 0) + 1;
      }

      // ✅ “Diğer” varyantlarını birleştir
      final mergedSchoolType = <String, int>{};
      for (final e in evizyonBySchoolType.entries) {
        final k = _normalizeSchoolType(e.key);
        mergedSchoolType[k] = (mergedSchoolType[k] ?? 0) + e.value;
      }

      setState(() {
        _branchTotals = branchTotals;
        _totalNorm = totalNorm;
        _totalKadrolu = totalKad;
        _totalSozlesmeli = totalSoz;

        _schoolCountByDistrict = schoolCountByDistrict;
        _teacherCountByDistrict = teacherCountByDistrict;

        _dykCoursesByLesson = dykCoursesByLesson;
        _dykStudentsByLesson = dykStudentsByLesson;

        _evizyonTotal = apps.length;
        _evizyonByDistrict = evizyonByDistrict;
        _evizyonBySchoolType = mergedSchoolType;

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // GitHub JSON -> List<Map<String,dynamic>> (records/data/... destekli)
  // =========================================================
  Future<List<Map<String, dynamic>>> _readJsonListFromRepo(
      String path, {
        bool forceRefresh = false,
      }) async {
    final dynamic decoded = await repo.getJson(
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
      final m = Map<String, dynamic>.from(decoded);

      for (final key in ['records', 'data', 'items', 'results', 'list']) {
        final v = m[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      return [m];
    }

    return [];
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _init(forceRefresh: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: () => _init(forceRefresh: true))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle(
            icon: Icons.person_outline,
            title: '1) Öğretmen Analizleri',
          ),
          const SizedBox(height: 8),
          _Card(
            title: 'Branş Bazlı Dağılım (Öğretmen Sayısı)',
            subtitle:
            'Yatay Bar • Öğretmen sayısı (kadrolu+sözleşmeli)',
            child: _horizontalBarTopN(
              data: _branchTotals,
              topN: 12,
              height: 360,
              valueLabel: 'Öğrt.',
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Norm / Kadrolu / Sözleşmeli',
            subtitle: 'İl geneli toplam',
            child: _pieChartNormKadroSoz(
              norm: _totalNorm,
              kadrolu: _totalKadrolu,
              sozlesmeli: _totalSozlesmeli,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.location_city_outlined,
            title: '2) İlçe Karşılaştırmaları',
          ),
          const SizedBox(height: 8),
          _Card(
            title: 'İlçelere Göre Karşılaştırma',
            subtitle: _showTeacherCount
                ? 'Gösterim: Öğretmen sayısı (kadrolu+sözleşmeli)'
                : 'Gösterim: Okul sayısı',
            trailing: SizedBox(
              height: 34,
              child: SegmentedButton<bool>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: true, label: Text('Öğrt.')),
                  ButtonSegment(value: false, label: Text('Okul')),
                ],
                selected: {_showTeacherCount},
                onSelectionChanged: (s) =>
                    setState(() => _showTeacherCount = s.first),
              ),
            ),
            child: _showTeacherCount
                ? _barChartTopN(
              data: _teacherCountByDistrict,
              topN: 20,
              height: 280,
              valueLabel: 'Öğrt.',
            )
                : _barChartTopN(
              data: _schoolCountByDistrict,
              topN: 20,
              height: 280,
              valueLabel: 'Okul',
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.menu_book_outlined,
            title: '3) DYK Kurs Analizi',
          ),
          const SizedBox(height: 8),
          _Card(
            title: 'Ders Bazlı Dağılım (Kurs Sayısı)',
            subtitle: 'Bar Chart (Top 12 ders)',
            child: _barChartTopN(
              data: _dykCoursesByLesson,
              topN: 12,
              height: 280,
              valueLabel: 'Kurs',
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Kümülatif Kurs (Top 12 ders)',
            subtitle: 'Line Chart (kümülatif toplam)',
            child: _lineChartCumulative(
              data: _dykCoursesByLesson,
              topN: 12,
              height: 280,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.rocket_launch_outlined,
            title: '4) E-Vizyon 62 Analizi',
          ),
          const SizedBox(height: 8),
          _Card(
            title: 'İlçe Bazlı Başvuru Oranı',
            subtitle: 'Toplam: $_evizyonTotal',
            child: _barChartTopN(
              data: _evizyonByDistrict,
              topN: 20,
              height: 280,
              valueLabel: 'Başv.',
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Okul Türü Katkısı',

            child: Padding(
              padding: const EdgeInsets.only(left: 10), // ✅ 8-12 arası deneyebilirsin
              child: _pieChartFromMap(
                data: _evizyonBySchoolType,
                height: 280,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Charts
  // =========================================================

  Widget _barChartTopN({
    required Map<String, int> data,
    required int topN,
    required double height,
    required String valueLabel,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(topN).toList();

    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Veri yok.'),
      );
    }

    String shortLabel(String s) {
      final t = s.trim();
      if (t.length <= 12) return t;
      return '${t.substring(0, 12)}…';
    }

    final maxY =
    top.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < top.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: top[i].value.toDouble(),
              width: 14,
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: groups,
          titlesData: FlTitlesData(
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: (maxY / 4).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 72,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= top.length) {
                    return const SizedBox.shrink();
                  }

                  final full = top[idx].key;
                  final label = shortLabel(full);

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Transform.rotate(
                      angle: -0.85,
                      child: SizedBox(
                        width: 110,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final e = top[group.x.toInt()];
                return BarTooltipItem(
                  '${e.key}\n$valueLabel: ${e.value}',
                  const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _horizontalBarTopN({
    required Map<String, int> data,
    required int topN,
    required double height,
    required String valueLabel,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(topN).toList();

    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Veri yok.'),
      );
    }

    // ✅ Label kısaltma (2. görseldeki taşma/çakışma için)
    String shortLabel(String s) {
      final t = s.trim();
      if (t.length <= 14) return t;
      return '${t.substring(0, 14)}…';
    }

    final maxY = top.first.value.toDouble();

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < top.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: top[i].value.toDouble(),
              width: 10,
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: RotatedBox(
        quarterTurns: 1,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.15,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            barGroups: groups,
            titlesData: FlTitlesData(
              rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 120, // ✅ daha fazla alan
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= top.length) {
                      return const SizedBox.shrink();
                    }
                    return RotatedBox(
                      quarterTurns: -1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          shortLabel(top[idx].key),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final e = top[group.x.toInt()];
                  return BarTooltipItem(
                    '${e.key}\n$valueLabel: ${e.value}',
                    const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pieChartNormKadroSoz({
    required int norm,
    required int kadrolu,
    required int sozlesmeli,
  }) {
    final total = norm + kadrolu + sozlesmeli;
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Veri yok.'),
      );
    }

    return SizedBox(
      height: 280,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 34,
          sectionsSpace: 2,
          sections: [
            PieChartSectionData(
              value: norm.toDouble(),
              title: 'Norm\n$norm',
              radius: 74,
              color: Theme.of(context).colorScheme.primary,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: kadrolu.toDouble(),
              title: 'Kadrolu\n$kadrolu',
              radius: 74,
              color: Theme.of(context).colorScheme.secondary,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: sozlesmeli.toDouble(),
              title: 'Söz.\n$sozlesmeli',
              radius: 74,
              color: Theme.of(context).colorScheme.tertiary,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Okul Türü Katkısı (Pie): çakışma yok + legend + tooltip + her dilim farklı renk
  /// ✅ Okul Türü Katkısı (Pie): çakışma yok + legend + dokununca seçili bilgi
  /// fl_chart eski sürüm uyumlu (tooltip sınıfları yok)
  Widget _pieChartFromMap({
    required Map<String, int> data,
    required double height,
  }) {
    // 1) Normalize (Diğer varyantlarını birleştir)
    final normalized = <String, int>{};
    for (final e in data.entries) {
      final k = _normalizeSchoolType(e.key);
      normalized[k] = (normalized[k] ?? 0) + e.value;
    }

    final total = normalized.values.fold<int>(0, (p, c) => p + c);
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Veri yok.'),
      );
    }

    // 2) Büyükten küçüğe sırala
    final entries = normalized.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 3) Top N + Diğer (label kalabalığını azaltır)
    const topN = 6;
    final top = entries.take(topN).toList();
    final restSum = entries.skip(topN).fold<int>(0, (p, e) => p + e.value);

    final finalEntries = <MapEntry<String, int>>[
      ...top,
      if (restSum > 0) MapEntry('Diğer', restSum),
    ];

    // 4) Renk paleti (her dilim farklı)
    const palette = <Color>[
      Color(0xFF1E88E5),
      Color(0xFFD81B60),
      Color(0xFF43A047),
      Color(0xFFF4511E),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFFFB8C00),
      Color(0xFF6D4C41),
    ];

    // 5) Dilim üstünde yazı: küçük dilimde kapalı, büyükte sadece %
    String titleFor(int value) {
      final pct = (value * 100.0) / total;
      if (pct < 7.0) return ''; // küçük dilimlerde yazı yok -> çakışma yok
      return '${pct.toStringAsFixed(0)}%';
    }

    Widget legend() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < finalEntries.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6), // ✅ ETİKETLERİ SAĞA ALIR
                    child: Text(
                      '${finalEntries[i].key}: ${finalEntries[i].value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
          ],
        ],
      );
    }

    int touchedIndex = -1;

    return StatefulBuilder(
      builder: (context, setLocal) {
        final sections = <PieChartSectionData>[];

        for (var i = 0; i < finalEntries.length; i++) {
          final e = finalEntries[i];
          final isTouched = i == touchedIndex;

          sections.add(
            PieChartSectionData(
              value: e.value.toDouble(),
              color: palette[i % palette.length],
              radius: isTouched ? 82 : 72,
              title: titleFor(e.value),
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              titlePositionPercentageOffset: 0.62,
            ),
          );
        }

        String selectedText() {
          if (touchedIndex < 0 || touchedIndex >= finalEntries.length) return '';
          final e = finalEntries[touchedIndex];
          final pct = (e.value * 100.0) / total;
          return '${e.key}: ${e.value}  (${pct.toStringAsFixed(1)}%)';
        }

        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 34,
                          sectionsSpace: 2,
                          sections: sections,
                          // ✅ Eski fl_chart uyumlu: tooltip yok, sadece touchCallback
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (event, resp) {
                              final idx = resp?.touchedSection
                                  ?.touchedSectionIndex ??
                                  -1;
                              setLocal(() => touchedIndex = idx);
                            },
                          ),
                        ),
                      ),
                    ),
                    if (selectedText().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          selectedText(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(child: legend()),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _lineChartCumulative({
    required Map<String, int> data,
    required int topN,
    required double height,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(topN).toList();

    if (top.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Veri yok.'),
      );
    }

    String shortLabel(String s) {
      final t = s.trim();
      if (t.length <= 12) return t;
      return '${t.substring(0, 12)}…';
    }

    int cum = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < top.length; i++) {
      cum += top[i].value;
      spots.add(FlSpot(i.toDouble(), cum.toDouble()));
    }

    final maxY = cum.toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.1,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: (maxY / 4).clamp(1, double.infinity),
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 72,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= top.length) {
                    return const SizedBox.shrink();
                  }

                  final full = top[i].key;
                  final label = shortLabel(full);

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Transform.rotate(
                      angle: -0.85,
                      child: SizedBox(
                        width: 110,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: Theme.of(context).colorScheme.primary,
              dotData: const FlDotData(show: true),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  final idx = s.x.toInt();
                  final name =
                  (idx >= 0 && idx < top.length) ? top[idx].key : '';
                  return LineTooltipItem(
                    '$name\nKümülatif: ${s.y.toInt()}',
                    const TextStyle(fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // Helpers
  // =========================================================

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString().trim();
    return int.tryParse(s) ?? 0;
  }

  int _sumBranchKadrolu(Map<String, dynamic> okul) {
    final branslar = (okul['branslar'] is List) ? List.from(okul['branslar']) : const [];
    int sum = 0;
    for (final b in branslar) {
      if (b is! Map) continue;
      final bm = Map<String, dynamic>.from(b);
      sum += _asInt(bm['kadrolu'] ?? bm['KADROLU']);
    }
    return sum;
  }

  int _sumBranchSozlesmeli(Map<String, dynamic> okul) {
    final branslar = (okul['branslar'] is List) ? List.from(okul['branslar']) : const [];
    int sum = 0;
    for (final b in branslar) {
      if (b is! Map) continue;
      final bm = Map<String, dynamic>.from(b);
      sum += _asInt(bm['sozlesmeli'] ?? bm['SOZLESMELI']);
    }
    return sum;
  }


  String _normalizeDistrict(String s) {
    final t = s.trim();
    if (t.isEmpty) return '-';
    final lower = t.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _inferSchoolTypeFromName(String name) {
    final s = name.toLowerCase();
    if (s.contains('fen lisesi')) return 'Fen Lisesi';
    if (s.contains('ilkokul')) return 'İlkokul';
    if (s.contains('ortaokul')) return 'Ortaokul';
    if (s.contains('anaokul') ||
        s.contains('anasınıf') ||
        s.contains('anasinif')) {
      return 'Anaokulu';
    }
    if (s.contains('mesleki') || s.contains('mtal') || s.contains('teknik')) {
      return 'MTAL';
    }
    if (s.contains('bilim') || s.contains('sanat') || s.contains('bilsem')) {
      return 'BİLSEM';
    }
    if (s.contains('imam hatip')) return 'İHL';
    if (s.contains('özel eğitim')) return 'Özel Eğitim';
    if (s.contains('anadolu lisesi')) return 'Anadolu Lisesi';
    if (s.contains('rehberlik')) return 'RAM';
    if (s.contains('milli eğitim')) return 'MEM';
    if (s.contains('lisesi')) return 'Lise';
    return 'Diğer';
  }

  String _normalizeSchoolType(String type) {
    var t = type.trim();
    if (t.isEmpty) return 'Diğer';

    final low = t.toLowerCase();

    if (low == 'diger' ||
        low == 'diğer' ||
        low.contains('diger') ||
        low.contains('diğer') ||
        low == 'other') {
      return 'Diğer';
    }

    if (low == 'fen lisesi') return 'Fen Lisesi';
    if (low == 'anadolu lisesi') return 'Anadolu Lisesi';
    if (low == 'anaokulu') return 'Anaokulu';
    if (low == 'ilkokul') return 'İlkokul';
    if (low == 'ortaokul') return 'Ortaokul';
    if (low == 'ihl') return 'İHL';
    if (low == 'mtal') return 'MTAL';

    return t;
  }
}

// =========================================================
// Small UI pieces
// =========================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null || trailing != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: const TextStyle(color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

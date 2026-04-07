import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ✅ Rapor servislerin (GitHub JSON -> JsonRepository üzerinden)
import 'package:il_mem_yonetim/core/reports/report_data_service.dart';

// ✅ E-Vizyon servisi (Google Sheets)
import 'package:il_mem_yonetim/features/projects/data/evizyon62_service.dart';

/// Router’da extra olarak taşıyacağımız argüman
class PdfPreviewArgs {
  final String title;
  final Uint8List bytes;
  final String fileName;

  PdfPreviewArgs({
    required this.title,
    required this.bytes,
    required this.fileName,
  });
}

/// PDF önizleme sayfası (flutter_pdfview)
class PdfPreviewPage extends StatefulWidget {
  final PdfPreviewArgs args;
  const PdfPreviewPage({super.key, required this.args});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  String? _filePath;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = '${stamp}_${widget.args.fileName}';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(widget.args.bytes, flush: true);
      setState(() {
        _filePath = file.path;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final path = await ReportsPage.savePdfToDevice(
      bytes: widget.args.bytes,
      fileName: widget.args.fileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF kaydedildi: $path'),
        action: SnackBarAction(
          label: 'AÇ',
          onPressed: () => OpenFilex.open(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'İndir',
            icon: const Icon(Icons.download_outlined),
            onPressed: _download,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
          ? Center(child: Text(_err!))
          : PDFView(
        filePath: _filePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(
            icon: Icons.school_outlined,
            title: '1) Okul & Personel Raporları',
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'Öğretmen Dağılım Raporu',
            subtitle: 'İl/İlçe • Norm/Kadrolu/Sözleşmeli • Branş kırılımı',
            fileName: 'Tunceli_Ogretmen_Dagilimi_$year.pdf',
            onBytes: () => _teacherDistributionBytes(year: year),
          ),
          const SizedBox(height: 10),
          _ReportCard(
            title: 'Okul Bazlı Detay Raporu',
            subtitle:
            'Okul adı • Tür (tahmini) • Öğretmen sayısı • Branş dağılımı • Taşımalı durumu',
            fileName: 'Tunceli_Okul_Detay_$year.pdf',
            onBytes: () => _schoolDetailBytes(year: year),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.directions_bus_outlined,
            title: '2) Taşımalı Eğitim Raporları',
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'Taşımalı Eğitim Raporu (Özel / Orta / Temel)',
            subtitle:
            'İlçe bazlı öğrenci sayıları • Merkez okul sayısı • Toplam taşımalı',
            fileName: 'Tunceli_Tasimali_Egitim_$year.pdf',
            onBytes: () => _transportationBytes(year: year),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.menu_book_outlined,
            title: '3) DYK Kursları Raporları',
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'DYK Kursları Raporu',
            subtitle:
            'İlçe bazlı kurs sayısı • Öğrenci sayıları • Ders türüne göre dağılım + Okul bazlı liste',
            fileName: 'Tunceli_DYK_$year.pdf',
            onBytes: () => _dykBytes(year: year),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            icon: Icons.rocket_launch_outlined,
            title: '4) E-Vizyon 62 Raporları',
          ),
          const SizedBox(height: 8),
          _ReportCard(
            title: 'E-Vizyon 62 Başvuru Raporu',
            subtitle: 'Başvuru sayıları • İlçe dağılımı • Okul türüne göre katılım',
            fileName: 'Tunceli_Evizyon62_$year.pdf',
            onBytes: () => _evizyonBytes(year: year),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================================
  // ✅ Kaydet (Android/iOS)
  // =========================================================
  static Future<String> savePdfToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    Directory baseDir;

    if (Platform.isAndroid) {
      baseDir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final reportsDir = Directory('${baseDir.path}/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final file = File('${reportsDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // =========================================================
  // ✅ Türkçe karakter: font embed
  // =========================================================
  static Future<(pw.Font base, pw.Font bold)> _loadPdfFonts() async {
    final regularData =
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    final base = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    return (base, bold);
  }

  static pw.Document _newDocWithFonts(pw.Font base, pw.Font bold) {
    return pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold),
    );
  }

  static pw.Widget _pdfHeader({
    required pw.Font base,
    required pw.Font bold,
    required String title,
    required int year,
    String? extraLine,
  }) {
    final now = DateTime.now();
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'T.C. TUNCELİ İL MİLLÎ EĞİTİM MÜDÜRLÜĞÜ',
          style: pw.TextStyle(font: bold, fontSize: 12),
        ),
        pw.SizedBox(height: 6),
        pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 18)),
        pw.SizedBox(height: 4),
        pw.Text('Dönem: $year', style: pw.TextStyle(font: base)),
        pw.Text('Oluşturulma: ${fmt.format(now)}',
            style: pw.TextStyle(font: base)),
        if (extraLine != null && extraLine.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(extraLine, style: pw.TextStyle(font: base, fontSize: 10)),
        ],
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _kv(pw.Font base, pw.Font bold, String k, String v) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 160,
          child: pw.Text(k, style: pw.TextStyle(font: bold)),
        ),
        pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: base))),
      ],
    );
  }

  static pw.Widget _fixedWidthTable({
    required pw.Font base,
    required pw.Font bold,
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
    bool zebra = true,
  }) {
    assert(headers.length == widths.length);

    return pw.Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      border: pw.TableBorder.all(color: PdfColors.grey400),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers
              .map(
                (h) => pw.Padding(
              padding:
              const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: pw.Text(h, style: pw.TextStyle(font: bold)),
            ),
          )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: zebra && idx.isOdd
                ? const pw.BoxDecoration(color: PdfColors.grey100)
                : null,
            children: row
                .map(
                  (cell) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 6, horizontal: 6),
                child: pw.Text(
                  cell,
                  style: pw.TextStyle(font: base),
                  softWrap: true,
                ),
              ),
            )
                .toList(),
          );
        }),
      ],
    );
  }

  static String _topNSummary(Map<String, int> map, int n) {
    if (map.isEmpty) return '-';
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => '${e.key}: ${e.value}').join(' • ');
  }

  // =========================
  // 1) Öğretmen Dağılım (BYTES) ✅ GitHub
  // =========================
  static Future<Uint8List> _teacherDistributionBytes({required int year}) async {
    final (base, bold) = await _loadPdfFonts();
    final data = await ReportDataService.buildTeacherDistributionByDistrict();

    final rows = data
        .map((r) => [
      r.ilce,
      r.norm.toString(),
      r.kadrolu.toString(),
      r.sozlesmeli.toString(),
      r.toplam.toString(),
      _topNSummary(r.branchTotals, 6),
    ])
        .toList();

    final doc = _newDocWithFonts(base, bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _pdfHeader(
            base: base,
            bold: bold,
            title: 'Öğretmen Dağılım Raporu',
            year: year,
          ),
          _kv(
            base,
            bold,
            'Kapsam',
            'İlçe bazlı; Norm/Kadrolu/Sözleşmeli; Branş kırılımı (kadrolu+sözleşmeli)',
          ),
          pw.SizedBox(height: 10),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const [
              'İlçe',
              'Norm',
              'Kad.',
              'Söz.',
              'Top.',
              'Branş Dağılımı (İlk 6)'
            ],
            widths: const [2, 1, 1, 1, 1, 5],
            rows: rows.isEmpty ? const [['-', '0', '0', '0', '0', '-']] : rows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // 1) Okul Bazlı Detay (BYTES) ✅ GitHub
  // =========================
  static Future<Uint8List> _schoolDetailBytes({required int year}) async {
    final (base, bold) = await _loadPdfFonts();
    final data = await ReportDataService.buildSchoolDetails();

    final rows = data
        .map((s) => [
      s.ilce,
      s.okulAdi,
      s.tur,
      s.toplam.toString(),
      _topNSummary(s.branchTotals, 6),
      s.tasimali ? 'Evet' : 'Hayır',
    ])
        .toList();

    final doc = _newDocWithFonts(base, bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _pdfHeader(
            base: base,
            bold: bold,
            title: 'Okul Bazlı Detay Raporu',
            year: year,
          ),
          _kv(
            base,
            bold,
            'İçerik',
            'İlçe; Okul adı; Tür (ad üzerinden tahmin); Öğretmen sayısı; Branş dağılımı; Taşımalı',
          ),
          pw.SizedBox(height: 10),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const [
              'İlçe',
              'Okul',
              'Tür',
              'Öğr.',
              'Branş (İlk 6)',
              'Taşımalı'
            ],
            widths: const [2, 4, 2, 1, 6, 1],
            rows: rows.isEmpty ? const [['-', '-', '-', '0', '-', '-']] : rows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // 2) Taşımalı (BYTES) ✅ GitHub
  // =========================
  static Future<Uint8List> _transportationBytes({required int year}) async {
    final (base, bold) = await _loadPdfFonts();
    final data = await ReportDataService.buildTransportationAgg();

    final rows = data
        .map((r) => [
      r.ilce,
      r.ozel.toString(),
      r.orta.toString(),
      r.temel.toString(),
      r.merkezOkulSayisi.toString(),
      r.toplam.toString(),
    ])
        .toList();

    final doc = _newDocWithFonts(base, bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _pdfHeader(
            base: base,
            bold: bold,
            title: 'Taşımalı Eğitim Raporu',
            year: year,
          ),
          _kv(
            base,
            bold,
            'Kapsam',
            'Özel/Orta/Temel ayrı; İlçe bazlı öğrenci sayıları; Merkez okul sayısı; Toplam',
          ),
          pw.SizedBox(height: 10),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const [
              'İlçe',
              'Özel',
              'Orta',
              'Temel',
              'Merkez Okul',
              'Toplam'
            ],
            widths: const [3, 1, 1, 1, 1.5, 1],
            rows: rows.isEmpty ? const [['-', '0', '0', '0', '0', '0']] : rows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // 3) DYK (BYTES) ✅ GitHub  -> Özet + Okul Bazlı Liste
  // =========================
  static Future<Uint8List> _dykBytes({required int year}) async {
    final (base, bold) = await _loadPdfFonts();

    final agg = await ReportDataService.buildDykAgg();
    final summaryRows = agg
        .map((r) => [
      r.ilce,
      r.kursSayisi.toString(),
      r.ogrenciSayisi.toString(),
      _topNSummary(r.dersKurs, 8),
    ])
        .toList();

    final schools = await ReportDataService.buildDykSchools();
    final schoolRows = schools.map((s) {
      final dersOzet = _topNSummary(s.dersKurs, 6);
      return [
        s.ilce,
        s.okulAdi,
        s.kursSayisi.toString(),
        s.dersKurs.length.toString(),
        s.ogrenciSayisi.toString(),
        dersOzet,
      ];
    }).toList();

    final doc = _newDocWithFonts(base, bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _pdfHeader(
            base: base,
            bold: bold,
            title: 'DYK Kursları Raporu',
            year: year,
          ),
          _kv(
            base,
            bold,
            'Kapsam',
            'İlçe bazlı kurs sayısı; Öğrenci sayıları; Ders türüne göre dağılım (kurs) + okul bazlı detay',
          ),
          pw.SizedBox(height: 10),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const ['İlçe', 'Kurs', 'Öğrenci', 'Ders Dağılımı (İlk 8)'],
            widths: const [2, 1, 1, 6],
            rows: summaryRows.isEmpty
                ? const [
              ['-', '0', '0', '-']
            ]
                : summaryRows,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Okul Bazlı Kurs Listesi',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 8),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const [
              'İlçe',
              'Okul',
              'Kurs',
              'Ders',
              'Öğr.',
              'Ders Özeti (İlk 6)'
            ],
            widths: const [2, 5, 1, 1, 1, 5],
            rows: schoolRows.isEmpty
                ? const [
              ['-', '-', '0', '0', '0', '-']
            ]
                : schoolRows,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // =========================
  // 4) E-Vizyon 62 (BYTES)  (Sheets -> aynı)
  // =========================
  static Future<Uint8List> _evizyonBytes({required int year}) async {
    final (base, bold) = await _loadPdfFonts();
    final service = Evizyon62Service();
    final apps = await service.fetchApplications();

    final total = apps.length;
    final Map<String, int> byDistrict = {};
    final Map<String, int> bySchoolType = {};

    for (final a in apps) {
      final d = _normalizeDistrict(a.district);
      byDistrict[d] = (byDistrict[d] ?? 0) + 1;

      final type = _inferSchoolTypeFromName(a.school);
      bySchoolType[type] = (bySchoolType[type] ?? 0) + 1;
    }

    final districtEntries = byDistrict.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final districtRows =
    districtEntries.map((e) => [e.key, e.value.toString()]).toList();

    final schoolTypeSummary = _topNSummary(bySchoolType, 8);

    final doc = _newDocWithFonts(base, bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _pdfHeader(
            base: base,
            bold: bold,
            title: 'E-Vizyon 62 Başvuru Raporu',
            year: year,
            extraLine: 'Kaynak: Google Sheets (CSV) • Toplam başvuru: $total',
          ),
          _kv(base, bold, 'Kapsam',
              'Başvuru sayıları; İlçe dağılımı; Okul türüne göre katılım'),
          pw.SizedBox(height: 8),
          _kv(base, bold, 'Okul türü özeti (tahmini)', schoolTypeSummary),
          pw.SizedBox(height: 12),
          pw.Text('İlçe Dağılımı',
              style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 8),
          _fixedWidthTable(
            base: base,
            bold: bold,
            headers: const ['İlçe', 'Başvuru'],
            widths: const [4, 1],
            rows: districtRows.isEmpty ? const [['-', '0']] : districtRows,
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Not: Okul türü, okul/kurum adından tahmin edilmiştir (İlkokul/Ortaokul/Lise/MTAL/İHL vb.).',
            style: pw.TextStyle(font: base, fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _normalizeDistrict(String s) {
    final t = s.trim();
    if (t.isEmpty) return '-';
    final lower = t.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  static String _inferSchoolTypeFromName(String name) {
    final s = name.toLowerCase();
    if (s.contains('fen lisesi')) return 'Fen Lisesi';
    if (s.contains('ilkokul')) return 'İlkokul';
    if (s.contains('ortaokul')) return 'Ortaokul';
    if (s.contains('anaokul') || s.contains('anasınıf') || s.contains('anasinif')) {
      return 'Anaokulu';
    }
    if (s.contains('mesleki') || s.contains('mtal') || s.contains('teknik')) return 'MTAL';
    if (s.contains('bilim') || s.contains('sanat') || s.contains('bilsem')) return 'BİLSEM';
    if (s.contains('imam hatip')) return 'İHL';
    if (s.contains('özel eğitim')) return 'Özel Eğitim';
    if (s.contains('anadolu lisesi')) return 'Anadolu Lisesi';
    if (s.contains('rehberlik')) return 'RAM';
    if (s.contains('milli eğitim')) return 'MEM';
    if (s.contains('lisesi')) return 'Lise';
    return 'Diğer';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

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

class _ReportCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String fileName;
  final Future<Uint8List> Function() onBytes;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.onBytes,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _loading = false;

  Future<void> _openPreview(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.onBytes();
      if (!mounted) return;

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName =
      widget.fileName.replaceFirst('.pdf', '_$stamp.pdf');

      context.push(
        '/pdf-preview',
        extra: PdfPreviewArgs(
          title: widget.title,
          bytes: bytes,
          fileName: uniqueName,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.fileName,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.visibility_outlined),
                label: Text(_loading ? 'Hazırlanıyor…' : 'Önizle'),
                onPressed: _loading ? null : () => _openPreview(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

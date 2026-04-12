import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/models/school.dart';
import 'package:il_mem_yonetim/core/data/json_providers.dart';

// ✅ Planlı Denetim (Apps Script API)
import '../inspection/data/inspection_api.dart';

// E-Vizyon 62
import '../projects/data/evizyon62_service.dart';
import '../projects/presentation/projects_page.dart';

// Materyal Komisyonu
import 'material_komisyonu_page.dart';

// DYK
import 'dyk_kurslari_page.dart';

// Taşımalı Eğitim
import 'tasimali_egitim_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final evizyonService = Evizyon62Service();

  // ✅ Apps Script Web App URL (Planlı Denetim)
  final inspectionApi = InspectionApi(
    baseUrl:
    "https://script.google.com/macros/s/AKfycbxtjdFhKIa-Fb_kHxh3eqO6WZ52J8tXdDNY7N-HoMLkKiSlIOTNWKHDDdRZTyGZI_Cx/exec",
    apiKey: "MEM_DENETIM_2026",
  );

  List<School> schools = [];

  late Future<int> evizyonCountFuture;
  late Future<int> materialCountFuture;
  late Future<int> dykKursSayisiFuture;
  late Future<int> tasimaliToplamFuture;
  late Future<int> plannedInspectionCountFuture;
  late Future<int> studentCountFuture;

  @override
  void initState() {
    super.initState();

    evizyonCountFuture = _loadEvizyonCount();
    materialCountFuture = _loadMaterialKomisyonuCount();
    dykKursSayisiFuture = _loadDykKursSayisi();
    tasimaliToplamFuture = _loadTasimaliToplam();
    plannedInspectionCountFuture = _loadPlannedInspectionCount();
    studentCountFuture = _loadStudentCount();

    _loadSchoolsFromGitHub(forceRefresh: true);
  }

  List<dynamic> _extractRecords(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final r = decoded['records'];
      if (r is List) return r;
      return const [];
    }
    if (decoded is List) return decoded;
    return const [];
  }

  Future<void> _loadSchoolsFromGitHub({bool forceRefresh = false}) async {
    try {
      final repo = ref.read(jsonRepositoryProvider);

      if (forceRefresh) {
        await repo.clearCache('tunceli_okullar.json');
      }

      final decoded = await repo.getJson(
        'tunceli_okullar.json',
        forceRefresh: forceRefresh,
        cacheBust: true,
      );

      final records = _extractRecords(decoded);

      final parsed = records
          .whereType<Map>()
          .map((e) => School.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final unique = <String, School>{};
      for (final s in parsed) {
        final key =
        s.kurumKodu.isNotEmpty ? s.kurumKodu : '${s.ilce}||${s.okulAdi}';
        unique[key] = s;
      }
      final list = unique.values.toList();

      debugPrint('DASHBOARD OKUL SAYISI: ${list.length}');
      debugPrint(
        'DASHBOARD OGRT TOPLAM: ${list.fold<int>(0, (sum, s) => sum + (s.kadrolu ?? 0) + (s.sozlesmeli ?? 0))}',
      );

      if (!mounted) return;
      setState(() => schools = list);
    } catch (e) {
      debugPrint('DASHBOARD OKUL FETCH HATASI: $e');

      if (!mounted) return;
      setState(() => schools = const []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Okul verisi alınamadı: $e')),
      );
    }
  }

  Future<int> _loadEvizyonCount() async {
    final list = await evizyonService.fetchApplications();
    return list.length;
  }

  Future<int> _loadPlannedInspectionCount() async {
    final records = await inspectionApi.listInspections(limit: 5000);
    return records.length;
  }

  Future<int> _loadMaterialKomisyonuCount({bool forceRefresh = false}) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      'material_komisyonu.json',
      forceRefresh: forceRefresh,
      cacheBust: true,
    );

    if (decoded is! Map<String, dynamic>) return 0;
    final members = decoded['members'];
    return members is List ? members.length : 0;
  }

  Future<int> _loadDykKursSayisi({bool forceRefresh = false}) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      'dyk_kurslari.json',
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    final records = _extractRecords(decoded);

    int toplam = 0;
    for (final r in records) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final v = m['KURS_SAYISI'] ?? m['kurs_sayisi'];

      if (v is int) {
        toplam += v;
      } else if (v is double) {
        toplam += v.toInt();
      } else {
        toplam += int.tryParse(v?.toString().trim() ?? '') ?? 0;
      }
    }
    return toplam;
  }

  Future<int> _loadTasimaliToplam({bool forceRefresh = false}) async {
    Future<int> countPath(String path) async {
      final decoded = await ref.read(jsonRepositoryProvider).getJson(
        path,
        forceRefresh: forceRefresh,
        cacheBust: forceRefresh,
      );
      final records = _extractRecords(decoded);
      return records.length;
    }

    final ozel = await countPath('tasimali/tasimali_ozel.json');
    final orta = await countPath('tasimali/tasimali_orta.json');
    final temel = await countPath('tasimali/tasimali_temel.json');
    return ozel + orta + temel;
  }

  Future<int> _loadStudentCount({bool forceRefresh = false}) async {
    final decoded = await ref.read(jsonRepositoryProvider).getJson(
      'ogrenci_sayilari.json',
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    if (decoded is! Map<String, dynamic>) return 0;

    final summary = decoded['summary'];
    if (summary is! Map<String, dynamic>) return 0;

    final ogrenci = summary['ogrenci_sayisi'];
    if (ogrenci is! Map<String, dynamic>) return 0;

    final toplam = ogrenci['toplam'];

    if (toplam is int) return toplam;
    if (toplam is double) return toplam.toInt();
    return int.tryParse(toplam?.toString() ?? '') ?? 0;
  }

  String _formatInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  Future<void> _refreshAll() async {
    setState(() {
      schools = const [];
      evizyonCountFuture = _loadEvizyonCount();
      materialCountFuture = _loadMaterialKomisyonuCount(forceRefresh: true);
      dykKursSayisiFuture = _loadDykKursSayisi(forceRefresh: true);
      tasimaliToplamFuture = _loadTasimaliToplam(forceRefresh: true);
      plannedInspectionCountFuture = _loadPlannedInspectionCount();
      studentCountFuture = _loadStudentCount(forceRefresh: true);
    });

    await _loadSchoolsFromGitHub(forceRefresh: true);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    final okulSayisi = schools.length;
    final ogretmenSayisi = schools.fold<int>(
      0,
          (sum, s) =>
      sum +
          s.branslar.fold<int>(
            0,
                (a, b) => a + (b.kadrolu ?? 0) + (b.sozlesmeli ?? 0),
          ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ana Sayfa',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 2.2 : 1.8,
            children: [
              _KpiCard(
                title: 'Okul',
                value: schools.isEmpty ? '—' : '$okulSayisi',
                onTap: () => context.go('/schools'),
              ),
              _FutureKpiCard(
                title: 'Öğrenci',
                futureValue: studentCountFuture,
                valueBuilder: (n) => _formatInt(n),
                onTap: () => context.go('/students'),
              ),
              _KpiCard(
                title: 'Öğretmen',
                value: schools.isEmpty ? '—' : _formatInt(ogretmenSayisi),
              ),
              _FutureKpiCard(
                title: 'E-Vizyon 62',
                futureValue: evizyonCountFuture,
                valueBuilder: (n) => '$n',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProjectsPage(initialTabIndex: 0),
                    ),
                  );
                },
              ),
              _FutureKpiCard(
                title: 'Planlı Denetim',
                futureValue: plannedInspectionCountFuture,
                valueBuilder: (n) => '$n',
                onTap: () => context.go('/inspection'),
              ),
              _FutureKpiCard(
                title: 'Materyal Komisyonu',
                futureValue: materialCountFuture,
                valueBuilder: (n) => '$n',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaterialKomisyonuPage(),
                  ),
                ),
              ),
              _FutureKpiCard(
                title: 'DYK Kursları',
                futureValue: dykKursSayisiFuture,
                valueBuilder: (n) => '$n',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DykKurslariPage()),
                ),
              ),
              _FutureKpiCard(
                title: 'Taşımalı Eğitim',
                futureValue: tasimaliToplamFuture,
                valueBuilder: (n) => '$n',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TasimaliEgitimPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Sosyal Medya Hesapları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SocialAction(
                label: 'Instagram',
                icon: FontAwesomeIcons.instagram,
                onTap: () => _openUrl('https://www.instagram.com/tunceliilmilliegitim'),
              ),
              _SocialAction(
                label: 'X',
                icon: FontAwesomeIcons.xTwitter,
                onTap: () => _openUrl('https://x.com/Tunceli_MEM'),
              ),
              _SocialAction(
                label: 'YouTube',
                icon: FontAwesomeIcons.youtube,
                onTap: () => _openUrl('https://www.youtube.com/TunceliMEM'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  final IconData? valueIcon;

  const _KpiCard({
    required this.title,
    required this.value,
    this.onTap,
    this.valueIcon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              if (valueIcon != null)
                Icon(valueIcon, size: 30, color: primary)
              else
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FutureKpiCard extends StatelessWidget {
  final String title;
  final Future<int> futureValue;
  final String Function(int) valueBuilder;
  final VoidCallback? onTap;

  const _FutureKpiCard({
    required this.title,
    required this.futureValue,
    required this.valueBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: futureValue,
      builder: (context, snap) {
        final value = snap.connectionState == ConnectionState.waiting
            ? '—'
            : snap.hasError
            ? '!'
            : valueBuilder(snap.data ?? 0);

        return Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SocialAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
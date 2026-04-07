import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/school_repository.dart';
import '../../core/models/school.dart';
import 'data/inspection_api.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({super.key});

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage> {
  final repo = const SchoolRepository();

  final api = InspectionApi(
    baseUrl:
    "https://script.google.com/macros/s/AKfycbxtjdFhKIa-Fb_kHxh3eqO6WZ52J8tXdDNY7N-HoMLkKiSlIOTNWKHDDdRZTyGZI_Cx/exec",
    apiKey: "MEM_DENETIM_2026",
  );

  bool loading = true;
  bool saving = false;

  // Aynı içerik hızlıca tekrar gönderilmesin
  String? _lastSubmitKey;

  List<School> allSchools = [];
  List<String> ilceler = [];

  String? selectedIlce;
  School? selectedSchool;

  final denetleyenCtrl = TextEditingController();
  final raporCtrl = TextEditingController();
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    final data = await repo.loadSchoolsFromAssets();
    final set = <String>{};

    for (final s in data) {
      final ilce = (s.ilce ?? "").trim();
      if (ilce.isNotEmpty) set.add(ilce);
    }

    final list = set.toList()..sort();

    if (!mounted) return;
    setState(() {
      allSchools = data;
      ilceler = list;
      loading = false;
    });
  }

  List<School> get filteredSchools {
    final ilce = selectedIlce;
    if (ilce == null) return [];
    final items = allSchools.where((s) => (s.ilce ?? "").trim() == ilce).toList();
    items.sort((a, b) => (a.okulAdi ?? "").compareTo(b.okulAdi ?? ""));
    return items;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: selectedDateTime ?? now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? now),
    );
    if (time == null) return;

    if (!mounted) return;
    setState(() {
      selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _prettyDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toastError(Object e) {
    final msg = e.toString();
    final shortMsg = msg.length > 160 ? "${msg.substring(0, 160)}..." : msg;
    _toast("Hata: $shortMsg");
  }

  void _goBackToHome({Object? result}) {
    if (!mounted) return;

    // 1) Stack varsa: güvenli pop
    if (context.canPop()) {
      context.pop(result);
      return;
    }

    // 2) Stack yoksa: router’dan "ilk tanımlı route" path’ine git
    final router = GoRouter.of(context);

    String? firstPathFromConfig() {
      final routes = router.configuration.routes;
      if (routes.isEmpty) return null;

      final first = routes.first;

      // GoRoute ise path vardır
      if (first is GoRoute) return first.path;

      // ShellRoute ise içindeki ilk GoRoute’un path’ini bul
      if (first is ShellRoute && first.routes.isNotEmpty) {
        final r = first.routes.first;
        if (r is GoRoute) return r.path;
      }

      return null;
    }

    final target = firstPathFromConfig();

    if (target != null && target.trim().isNotEmpty) {
      router.go(target);
    } else {
      _toast("Ana sayfa route bulunamadı (go_router config).");
    }
  }


  Future<void> _save() async {
    if (saving) return;

    final ilce = selectedIlce;
    final okul = selectedSchool;
    final denetleyen = denetleyenCtrl.text.trim();
    final rapor = raporCtrl.text.trim();
    final dt = selectedDateTime;

    if (ilce == null) return _toast("Lütfen ilçe seçin.");
    if (okul == null) return _toast("Lütfen okul seçin.");
    if (denetleyen.isEmpty) return _toast("Denetleyen kişi adını yazın.");
    if (dt == null) return _toast("Tarih ve saat seçin.");
    if (rapor.isEmpty) return _toast("Rapor yazın.");

    final submitKey =
        "$ilce|${(okul.kurumKodu ?? '').toString()}|$denetleyen|${dt.toIso8601String()}|$rapor";

    if (_lastSubmitKey == submitKey) {
      return _toast("Aynı kayıt zaten gönderildi (tekrar engellendi).");
    }

    setState(() => saving = true);

    try {
      await api.createInspection(
        il: "TUNCELI",
        ilce: ilce,
        kurumKodu: (okul.kurumKodu ?? "").toString(),
        okulAdi: (okul.okulAdi ?? "").toString(),
        denetleyen: denetleyen,
        tarihSaat: dt,
        rapor: rapor,
      );

      _lastSubmitKey = submitKey;

      // ✅ Başarı: snackBar yok, setState yok -> sadece çıkış
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goBackToHome(result: true);
      });

      return;
    } catch (e) {
      if (!mounted) return;
      _toastError(e);
    } finally {
      // Sayfa kapanmadıysa butonu tekrar aktif et
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    denetleyenCtrl.dispose();
    raporCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final okullar = filteredSchools;

    return Scaffold(
      appBar: AppBar(title: const Text("Denetim / Rehberlik")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: selectedIlce,
            isExpanded: true,
            items: ilceler
                .map(
                  (e) => DropdownMenuItem(
                value: e,
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            )
                .toList(),
            onChanged: saving
                ? null
                : (v) => setState(() {
              selectedIlce = v;
              selectedSchool = null;
            }),
            decoration: const InputDecoration(
              labelText: "İlçe",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<School>(
            value: selectedSchool,
            isExpanded: true,
            items: okullar.map((o) {
              final title = (o.okulAdi ?? "—").toString();
              final code = (o.kurumKodu ?? "").toString();

              return DropdownMenuItem<School>(
                value: o,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(code, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: saving ? null : (v) => setState(() => selectedSchool = v),
            decoration: InputDecoration(
              labelText: "Denetlenen Okul",
              border: const OutlineInputBorder(),
              helperText: selectedIlce == null
                  ? "Önce ilçe seçin"
                  : (okullar.isEmpty ? "Bu ilçede okul bulunamadı" : null),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: denetleyenCtrl,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: "Denetleyen (Ad Soyad)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: saving ? null : _pickDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Tarih / Saat",
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDateTime == null ? "Seçmek için dokunun" : _prettyDateTime(selectedDateTime!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: raporCtrl,
            enabled: !saving,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: "Denetim Raporu",
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(saving ? "Kaydediliyor..." : "Kaydet"),
            ),
          ),
        ],
      ),
    );
  }
}

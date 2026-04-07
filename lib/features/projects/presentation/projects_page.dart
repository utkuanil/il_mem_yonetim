import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';

import '../models/project_detail.dart';
import 'project_detail_page.dart';

// E-Vizyon 62
import '../data/evizyon62_service.dart';
import '../models/evizyon62_application.dart';
import 'evizyon62_detail_page.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const ProjectsPage({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final evizyonService = Evizyon62Service();

  List<ProjectDetail> ulusal = [];
  List<ProjectDetail> uluslararasi = [];
  bool loading = true;
  String? error;

  late Future<List<Evizyon62Application>> evizyonFuture;

  @override
  void initState() {
    super.initState();
    evizyonFuture = evizyonService.fetchApplications();
    _load();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;

      // ✅ E-Vizyon 62 de yenilensin (GitHub değil ama kullanıcı beklentisi)
      evizyonFuture = evizyonService.fetchApplications();
    });

    await _load(forceRefresh: true);
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

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final aDecoded = await ref.read(jsonRepositoryProvider).getJson(
        'projects/ulusal_projeler.json',
        forceRefresh: forceRefresh,
        cacheBust: forceRefresh,
      );

      final bDecoded = await ref.read(jsonRepositoryProvider).getJson(
        'projects/uluslararasi_projeler.json',
        forceRefresh: forceRefresh,
        cacheBust: forceRefresh,
      );

      final aList = _extractRecords(aDecoded);
      final bList = _extractRecords(bDecoded);

      final a = aList
          .whereType<Map>()
          .map((e) => ProjectDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final b = bList
          .whereType<Map>()
          .map((e) => ProjectDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      a.sort((x, y) => x.id.compareTo(y.id));
      b.sort((x, y) => x.id.compareTo(y.id));

      if (!mounted) return;
      setState(() {
        ulusal = a;
        uluslararasi = b;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Projeler',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile',
                ),
              ],
            ),
            const SizedBox(height: 12),

            const TabBar(
              tabs: [
                Tab(text: 'E-Vizyon 62'),
                Tab(text: 'Ulusal'),
                Tab(text: 'Uluslararası'),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                children: [
                  _Evizyon62Tab(future: evizyonFuture),

                  _ProjectsTabBody(
                    loading: loading,
                    error: error,
                    items: ulusal,
                  ),

                  _ProjectsTabBody(
                    loading: loading,
                    error: error,
                    items: uluslararasi,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsTabBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<ProjectDetail> items;

  const _ProjectsTabBody({
    required this.loading,
    required this.error,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Hata: $error'),
        ),
      );
    }
    return _ProjectList(items: items);
  }
}

class _Evizyon62Tab extends StatelessWidget {
  final Future<List<Evizyon62Application>> future;
  const _Evizyon62Tab({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evizyon62Application>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hata: ${snap.error}'),
            ),
          );
        }

        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Kayıt bulunamadı.'));

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final a = list[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(a.activityName.isNotEmpty ? a.activityName : '(Etkinlik adı yok)'),
                subtitle: Text('${a.fullName} • ${a.district}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Evizyon62DetailPage(app: a)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ProjectList extends StatelessWidget {
  final List<ProjectDetail> items;
  const _ProjectList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Kayıt bulunamadı.'));

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final p = items[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.work_outline),
            title: Text(p.ad),
            subtitle: (p.en ?? '').trim().isNotEmpty ? Text(p.en!) : null,
            trailing: Text(p.id, style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProjectDetailPage(project: p)),
              );
            },
          ),
        );
      },
    );
  }
}

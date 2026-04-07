import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:il_mem_yonetim/core/data/json_providers.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  late Future<Map<String, dynamic>> _studentDataFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _studentDataFuture = _loadStudentData();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadStudentData({bool forceRefresh = false}) async {
    final repo = ref.read(jsonRepositoryProvider);

    if (forceRefresh) {
      await repo.clearCache('ogrenci_sayilari.json');
    }

    final decoded = await repo.getJson(
      'ogrenci_sayilari.json',
      forceRefresh: forceRefresh,
      cacheBust: forceRefresh,
    );

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Öğrenci verisi beklenen formatta değil.');
  }

  Future<void> _refresh() async {
    setState(() {
      _studentDataFuture = _loadStudentData(forceRefresh: true);
    });
    await _studentDataFuture;
  }

  String _formatInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buf.write('.');
      }
    }
    return buf.toString();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci İstatistikleri'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _studentDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Öğrenci verisi alınamadı:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final summary = Map<String, dynamic>.from(
            (data['summary'] as Map?) ?? {},
          );

          final allRecords = ((data['records'] as List?) ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          allRecords.sort((a, b) {
            final aToplam = _asInt((a['ogrenci_sayisi'] as Map?)?['toplam']);
            final bToplam = _asInt((b['ogrenci_sayisi'] as Map?)?['toplam']);
            return bToplam.compareTo(aToplam);
          });

          final records = allRecords.where((item) {
            if (_searchText.isEmpty) return true;
            final ilce = (item['ilce']?.toString() ?? '').toLowerCase();
            return ilce.contains(_searchText);
          }).toList();

          final summaryStudents = Map<String, dynamic>.from(
            (summary['ogrenci_sayisi'] as Map?) ?? {},
          );
          final summarySchools = Map<String, dynamic>.from(
            (summary['okul_sayisi'] as Map?) ?? {},
          );
          final summaryInstitutions = Map<String, dynamic>.from(
            (summary['kurum_sayisi'] as Map?) ?? {},
          );

          final updatedAt = data['updated_at']?.toString() ?? '-';

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Genel Durum',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.2 : 1.10,
                  children: [
                    _SummaryCard(
                      title: 'Toplam Öğrenci',
                      value: _formatInt(_asInt(summaryStudents['toplam'])),
                      icon: Icons.groups_2_outlined,
                    ),
                    _SummaryCard(
                      title: 'Toplam Okul',
                      value: _formatInt(_asInt(summarySchools['toplam'])),
                      icon: Icons.school_outlined,
                    ),
                    _SummaryCard(
                      title: 'Toplam Kurum',
                      value: _formatInt(_asInt(summaryInstitutions['toplam'])),
                      icon: Icons.apartment_outlined,
                    ),
                    _SummaryCard(
                      title: 'İlçe Sayısı',
                      value: _formatInt(allRecords.length),
                      icon: Icons.location_city_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Text(
                  'Kademe Bazlı Öğrenci Dağılımı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                _InfoCard(
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Anaokulu',
                        value: _formatInt(_asInt(summaryStudents['anaokulu'])),
                      ),
                      const Divider(height: 20),
                      _StatRow(
                        label: 'İlkokul',
                        value: _formatInt(_asInt(summaryStudents['ilkokul'])),
                      ),
                      const Divider(height: 20),
                      _StatRow(
                        label: 'Ortaokul',
                        value: _formatInt(_asInt(summaryStudents['ortaokul'])),
                      ),
                      const Divider(height: 20),
                      _StatRow(
                        label: 'Lise',
                        value: _formatInt(_asInt(summaryStudents['lise'])),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'İlçe Bazlı Detaylar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'İlçe ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                      onPressed: () => _searchController.clear(),
                      icon: const Icon(Icons.clear),
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (records.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aramaya uygun ilçe bulunamadı.'),
                    ),
                  ),

                ...records.map((item) {
                  final ilce = item['ilce']?.toString() ?? '-';
                  final ogrenci = Map<String, dynamic>.from(
                    (item['ogrenci_sayisi'] as Map?) ?? {},
                  );
                  final okul = Map<String, dynamic>.from(
                    (item['okul_sayisi'] as Map?) ?? {},
                  );
                  final kurum = Map<String, dynamic>.from(
                    (item['kurum_sayisi'] as Map?) ?? {},
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1.5,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: CircleAvatar(
                        child: Text(
                          ilce.isNotEmpty ? ilce[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(
                        ilce,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Toplam Öğrenci: ${_formatInt(_asInt(ogrenci['toplam']))}',
                      ),
                      children: [
                        _SectionTitle(title: 'Öğrenci Sayıları'),
                        _StatRow(
                          label: 'Anaokulu',
                          value: _formatInt(_asInt(ogrenci['anaokulu'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'İlkokul',
                          value: _formatInt(_asInt(ogrenci['ilkokul'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Ortaokul',
                          value: _formatInt(_asInt(ogrenci['ortaokul'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Lise',
                          value: _formatInt(_asInt(ogrenci['lise'])),
                        ),
                        const Divider(height: 24),

                        _SectionTitle(title: 'Okul Sayıları'),
                        _StatRow(
                          label: 'Toplam',
                          value: _formatInt(_asInt(okul['toplam'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Özel',
                          value: _formatInt(_asInt(okul['ozel'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Resmî',
                          value: _formatInt(_asInt(okul['resmi'])),
                        ),
                        const Divider(height: 24),

                        _SectionTitle(title: 'Kurum Sayıları'),
                        _StatRow(
                          label: 'Toplam',
                          value: _formatInt(_asInt(kurum['toplam'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Özel',
                          value: _formatInt(_asInt(kurum['ozel'])),
                        ),
                        const SizedBox(height: 8),
                        _StatRow(
                          label: 'Resmî',
                          value: _formatInt(_asInt(kurum['resmi'])),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.update_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Veri tarihi: $updatedAt',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(icon, color: primary, size: 24),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
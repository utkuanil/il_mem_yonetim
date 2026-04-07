import 'package:flutter/material.dart';
import '../../core/models/school.dart';

class SchoolDetailPage extends StatelessWidget {
  final School school;
  const SchoolDetailPage({super.key, required this.school});

  @override
  Widget build(BuildContext context) {
    final norm = school.norm ?? 0;
    final kadrolu = school.kadrolu ?? 0;
    final soz = school.sozlesmeli ?? 0;
    final toplam = school.toplamOgretmen;
    final fark = school.normFarki;

    return Scaffold(
      appBar: AppBar(title: const Text('Okul Detay')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              school.okulAdi,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${school.ilce} • Kod: ${school.kurumKodu}'),
            const SizedBox(height: 16),

            // ✅ Genel norm analizi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Genel Norm Analizi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _row('Norm', '$norm'),
                    _row('Kadrolu', '$kadrolu'),
                    _row('Sözleşmeli', '$soz'),
                    const Divider(),
                    _row('Toplam Öğretmen', '$toplam'),
                    const SizedBox(height: 8),
                    _result(fark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Branş bazlı norm analizi (varsa göster)
            if (school.branslar.isNotEmpty) ...[
              const Text('Branş Bazlı Norm Analizi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...school.branslar.map(
                    (b) => Card(
                  child: ListTile(
                    title: Text(b.brans),
                    subtitle: Text(
                      'Norm: ${b.norm ?? 0}  Kadrolu: ${b.kadrolu ?? 0}  Söz: ${b.sozlesmeli ?? 0}',
                    ),
                    trailing: _BransChip(fark: b.fark),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ✅ Konum
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Konum'),
                subtitle: Text(
                  (school.latitude == null || school.longitude == null)
                      ? 'Konum bilgisi girilmemiş (latitude/longitude)'
                      : '${school.latitude}, ${school.longitude}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _result(int fark) {
    if (fark > 0) {
      return Text('Norm Açığı: $fark',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red));
    }
    if (fark == 0) {
      return const Text('Norm Dolu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green));
    }
    return Text('Norm Fazlası: ${fark.abs()}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange));
  }
}

class _BransChip extends StatelessWidget {
  final int fark;
  const _BransChip({required this.fark});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final String text;

    if (fark > 0) {
      bg = Colors.red;
      text = 'Açık: $fark';
    } else if (fark == 0) {
      bg = Colors.green;
      text = 'Dolu';
    } else {
      bg = Colors.orange;
      text = 'Fazla: ${fark.abs()}';
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import '../models/project_detail.dart';
class ProjectDetailPage extends StatelessWidget {
  final ProjectDetail project;
  const ProjectDetailPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proje Detay')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(project.ad, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if ((project.en ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(project.en!, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 16),

          _Section(title: 'Sorumlu Birim', child: Text(_v(project.sorumluBirim))),
          _Section(
            title: 'Proje Ortakları / Paydaşları',
            child: project.paydaslar.isEmpty
                ? const Text('—')
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: project.paydaslar.map((p) => Text('• $p')).toList(),
            ),
          ),
          _Section(title: 'Projenin Amacı', child: Text(_v(project.amac))),

          if (project.isInternational) ...[
            _Section(
              title: 'Pilot İller',
              child: project.pilotIller.isEmpty
                  ? const Text('—')
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: project.pilotIller.map((c) => Chip(label: Text(c))).toList(),
              ),
            ),
            _Section(title: 'Genel Hedefi', child: Text(_v(project.genelHedef))),
          ],

          _Section(
            title: 'Proje Başlangıç / Bitiş Tarihi',
            child: Text('${_v(project.baslangic)}  →  ${_v(project.bitis)}'),
          ),

          _Section(
            title: 'Bütçesi (Hizmet / Ekipman / Hibe)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hizmet: ${_v(project.butce.hizmet)}'),
                Text('Ekipman: ${_v(project.butce.ekipman)}'),
                Text('Hibe: ${_v(project.butce.hibe)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _v(String? s) => (s ?? '').trim().isEmpty ? '—' : s!.trim();
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

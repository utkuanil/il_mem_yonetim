import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/announcements_repository.dart';
import 'models/announcement.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final repo = const AnnouncementsRepository();

  bool loading = true;
  String? error;
  List<Announcement> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await repo.fetchAnnouncements();
      setState(() => items = data);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link açılamadı')),
      );
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$day.$m.$y';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duyurular',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: loading
                  ? ListView(
                children: [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
                  : (error != null)
                  ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Hata: $error')),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: _load,
                      child: const Text('Tekrar Dene'),
                    ),
                  )
                ],
              )
                  : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final a = items[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(a.title),
                      subtitle: _fmtDate(a.pubDate).isEmpty
                          ? null
                          : Text(_fmtDate(a.pubDate)),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(a.link),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

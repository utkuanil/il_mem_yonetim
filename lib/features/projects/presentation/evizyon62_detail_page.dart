import '../models/evizyon62_application.dart';

import 'package:flutter/material.dart';


class Evizyon62DetailPage extends StatelessWidget {
  final Evizyon62Application app;
  const Evizyon62DetailPage({super.key, required this.app});

  Widget _row(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value.isNotEmpty ? value : "-"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = app.activityName.isNotEmpty ? app.activityName : "E-Vizyon 62 Başvurusu";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          _row("Başvuran kişinin Adı Soyadı", app.fullName),
          _row("Ünvanı", app.title),
          _row("İlçesi", app.district),
          _row("Okulu/Kurumu", app.school),
          _row("Etkinliğin Tematik Alanı", app.thematicArea),
          _row("Etkinliğin Adı", app.activityName),
          _row("Etkinliğin amacını bir cümle ile ifade ediniz", app.purposeOneSentence),
          _row("Katılımcı sayısı", app.participantsText),
          _row("Bütçesi", app.budgetText),
        ],
      ),
    );
  }
}

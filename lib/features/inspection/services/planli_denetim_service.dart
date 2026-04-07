import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/planli_denetim.dart';

class PlanliDenetimService {
  static const _url =
      'https://docs.google.com/spreadsheets/d/1ZjgKEAhIWPZ3dOgf-Ap5YH2z1B9sNTlMSOtd3PYBm24/gviz/tq?tqx=out:json';

  static Future<List<PlanliDenetim>> fetchAll() async {
    final res = await http.get(Uri.parse(_url));

    if (res.statusCode != 200) {
      throw Exception('Google Sheet okunamadı');
    }

    // gviz JSON başında saçma text oluyor, onu temizliyoruz
    final jsonText =
    res.body.substring(res.body.indexOf('{'), res.body.lastIndexOf('}') + 1);

    final data = json.decode(jsonText);
    final rows = data['table']['rows'] as List;

    return rows
        .map((r) =>
        PlanliDenetim.fromRow(r['c'].map((e) => e?['v']).toList()))
        .toList();
  }
}

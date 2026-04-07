import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/school.dart';

class SchoolRepository {
  const SchoolRepository();

  Future<List<School>> loadSchoolsFromAssets() async {
    final jsonStr = await rootBundle.loadString('assets/data/tunceli_okullar.json');
    final list = (json.decode(jsonStr) as List).cast<dynamic>();
    return list.map((e) => School.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}

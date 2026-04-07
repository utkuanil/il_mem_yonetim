import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/project_detail.dart';

class ProjectsRepository {
  const ProjectsRepository();

  Future<List<ProjectDetail>> loadUlusal() async {
    final s = await rootBundle.loadString('assets/data/projects/ulusal_projeler.json');
    final list = (json.decode(s) as List).cast<dynamic>();
    return list.map((e) => ProjectDetail.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<ProjectDetail>> loadUluslararasi() async {
    final s = await rootBundle.loadString('assets/data/projects/uluslararasi_projeler.json');
    final list = (json.decode(s) as List).cast<dynamic>();
    return list.map((e) => ProjectDetail.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}

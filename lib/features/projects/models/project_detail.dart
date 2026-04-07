class ProjectBudget {
  final String? hizmet;
  final String? ekipman;
  final String? hibe;

  const ProjectBudget({this.hizmet, this.ekipman, this.hibe});

  factory ProjectBudget.fromJson(Map<String, dynamic> json) {
    return ProjectBudget(
      hizmet: json['hizmet']?.toString(),
      ekipman: json['ekipman']?.toString(),
      hibe: json['hibe']?.toString(),
    );
  }
}

class ProjectDetail {
  final String id;
  final String ad;
  final String? en;

  final String? sorumluBirim;
  final List<String> paydaslar;
  final String? amac;

  // Uluslararası projelere özel
  final List<String> pilotIller;
  final String? genelHedef;

  final String? baslangic;
  final String? bitis;

  final ProjectBudget butce;

  const ProjectDetail({
    required this.id,
    required this.ad,
    this.en,
    this.sorumluBirim,
    required this.paydaslar,
    this.amac,
    required this.pilotIller,
    this.genelHedef,
    this.baslangic,
    this.bitis,
    required this.butce,
  });

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    List<String> _list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return ProjectDetail(
      id: json['id'].toString(),
      ad: json['ad'].toString(),
      en: json['en']?.toString(),
      sorumluBirim: json['sorumlu_birim']?.toString(),
      paydaslar: _list(json['paydaslar']),
      amac: json['amac']?.toString(),
      pilotIller: _list(json['pilot_iller']),
      genelHedef: json['genel_hedef']?.toString(),
      baslangic: json['baslangic']?.toString(),
      bitis: json['bitis']?.toString(),
      butce: ProjectBudget.fromJson(
        (json['butce'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  bool get isInternational => id.startsWith('I-');
}

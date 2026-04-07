class PlanliDenetim {
  final String id;
  final String il;
  final String ilce;
  final String kurumKodu;
  final String okulAdi;
  final String denetleyen;
  final String tarihSaat;
  final String rapor;

  PlanliDenetim({
    required this.id,
    required this.il,
    required this.ilce,
    required this.kurumKodu,
    required this.okulAdi,
    required this.denetleyen,
    required this.tarihSaat,
    required this.rapor,
  });

  factory PlanliDenetim.fromRow(List<dynamic> row) {
    return PlanliDenetim(
      id: row[0]?.toString() ?? '',
      il: row[1]?.toString() ?? '',
      ilce: row[2]?.toString() ?? '',
      kurumKodu: row[3]?.toString() ?? '',
      okulAdi: row[4]?.toString() ?? '',
      denetleyen: row[5]?.toString() ?? '',
      tarihSaat: row[6]?.toString() ?? '',
      rapor: row[7]?.toString() ?? '',
    );
  }
}

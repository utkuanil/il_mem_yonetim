class Evizyon62Application {
  final String fullName; // Başvuran kişinin Adı Soyadı
  final String title; // Ünvanı
  final String district; // İlçesi
  final String school; // Okulu/Kurumu
  final String thematicArea; // Etkinliğin tematik alanı
  final String activityName; // Etkinliğin adı
  final String purposeOneSentence; // Amacı (1 cümle)
  final String participantsText; // Katılımcı sayısı
  final String budgetText; // Bütçe

  // Yeni alanlar
  final int year; // 2025, 2026
  final int month; // 0=tümü/tek form, 1=Ocak, 2=Şubat...
  final String monthLabel; // Tümü, Ocak, Şubat...
  final String sourceKey; // örn: 2025_0, 2026_1

  Evizyon62Application({
    required this.fullName,
    required this.title,
    required this.district,
    required this.school,
    required this.thematicArea,
    required this.activityName,
    required this.purposeOneSentence,
    required this.participantsText,
    required this.budgetText,
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.sourceKey,
  });
}
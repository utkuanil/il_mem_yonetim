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
  });
}

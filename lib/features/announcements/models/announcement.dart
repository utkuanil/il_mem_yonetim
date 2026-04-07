class Announcement {
  final String title;
  final String link;
  final DateTime? pubDate;
  final String? description;

  const Announcement({
    required this.title,
    required this.link,
    this.pubDate,
    this.description,
  });
}

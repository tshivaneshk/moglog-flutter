class Shortcut {
  final int id;
  final String title;
  final String data;
  final String type; // "APP" or "LINK"
  final String? iconUrl;
  final int dramaId;

  const Shortcut({
    this.id = 0,
    required this.title,
    required this.data,
    required this.type,
    this.iconUrl,
    this.dramaId = 0,
  });
}

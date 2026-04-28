enum SearchResultKind {
  app,
  settings,
  input,
  media,
  action,
}

class SearchResultItem {
  final String id;
  final SearchResultKind kind;
  final String title;
  final String subtitle;
  final String keywords;
  final bool locked;
  final bool enabled;
  final Map<String, dynamic> payload;

  const SearchResultItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.keywords = '',
    this.locked = false,
    this.enabled = true,
    this.payload = const <String, dynamic>{},
  });
}

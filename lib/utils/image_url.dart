/// Normalizes artwork URLs returned by catalog providers before handing them
/// to Flutter's image pipeline. Some Zing-compatible responses use protocol-
/// relative or legacy HTTP CDN URLs, which otherwise render as a blank image
/// on platforms that only allow secure resources.
String normalizeImageUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  if (trimmed.startsWith('http://')) {
    return 'https://${trimmed.substring('http://'.length)}';
  }
  return trimmed;
}

/// Uploads a post's photos one after another and returns their upload keys in the order the user
/// arranged them (position 0 is the cover photo). Sequential, not parallel: each photo is a 0.5–1.5 MB
/// PUT on mobile data, and one at a time gives a meaningful "Laen fotot 2/5" progress. The first
/// failure stops the run.
Future<List<String>> uploadInOrder<T>(
  List<T> items,
  Future<String> Function(T item, int index) upload, {
  void Function(int done, int total)? onProgress,
}) async {
  final keys = <String>[];
  for (var i = 0; i < items.length; i++) {
    onProgress?.call(i, items.length);
    keys.add(await upload(items[i], i));
  }
  onProgress?.call(items.length, items.length);
  return keys;
}

/// Moves the photo at `from` to the front (cover) without changing the others' order.
List<T> makeCover<T>(List<T> items, int from) {
  if (from <= 0 || from >= items.length) return [...items];
  final copy = [...items];
  final cover = copy.removeAt(from);
  return [cover, ...copy];
}

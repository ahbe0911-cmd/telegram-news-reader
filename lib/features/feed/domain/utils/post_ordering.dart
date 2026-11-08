import '../entities/post.dart';

/// One deterministic order for all sources, pages, and refreshes.
/// Undated messages follow dated news; equal timestamps use IDs to avoid
/// unpredictable reordering between rebuilds.
int comparePostsNewestFirst(Post a, Post b) {
  final aTime = a.sortTimestamp;
  final bTime = b.sortTimestamp;
  if (aTime == null && bTime == null) return a.id.compareTo(b.id);
  if (aTime == null) return 1;
  if (bTime == null) return -1;
  final comparison = bTime.compareTo(aTime);
  return comparison != 0 ? comparison : a.id.compareTo(b.id);
}

import '../../models/tracked_item.dart';
import '../models/due_status.dart';

/// Lowercases [s] and strips Vietnamese diacritics (đ → d included), so a
/// search for "loc nuoc" finds "Lõi lọc nước".
String foldDiacritics(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_folded[ch] ?? ch);
  }
  return out.toString();
}

const _groups = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậ',
  'e': 'èéẻẽẹêềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọôồốổỗộơờớởỡợ',
  'u': 'ùúủũụưừứửữự',
  'y': 'ỳýỷỹỵ',
  'd': 'đ',
};

final Map<String, String> _folded = {
  for (final entry in _groups.entries)
    for (final rune in entry.value.runes) String.fromCharCode(rune): entry.key,
};

/// What the item list is narrowed to. Empty = everything.
class ItemFilter {
  const ItemFilter({
    this.query = '',
    this.categories = const {},
    this.attentionOnly = false,
  });

  /// Matched (diacritic- and case-insensitively) against name and notes.
  final String query;

  /// Empty = any category.
  final Set<ItemCategory> categories;

  /// Only items that need looking at: overdue, due soon, or with a stale
  /// reading.
  final bool attentionOnly;

  bool get isActive =>
      query.trim().isNotEmpty || categories.isNotEmpty || attentionOnly;

  ItemFilter copyWith({
    String? query,
    Set<ItemCategory>? categories,
    bool? attentionOnly,
  }) => ItemFilter(
    query: query ?? this.query,
    categories: categories ?? this.categories,
    attentionOnly: attentionOnly ?? this.attentionOnly,
  );

  bool matches(TrackedItem item, DueStatus status) {
    if (categories.isNotEmpty && !categories.contains(item.category)) {
      return false;
    }
    if (attentionOnly &&
        !(status.isOverdue || status.isDueSoon || status.isReadingStale)) {
      return false;
    }
    final words = foldDiacritics(
      query,
    ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = foldDiacritics('${item.name} ${item.notes}');
    // Every word must appear somewhere, in any order.
    return words.every(haystack.contains);
  }
}

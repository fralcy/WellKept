import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/models/due_status.dart';
import 'package:well_kept/core/utils/item_filter.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  const ok = DueStatus(type: RecurrenceType.byTime);
  const dueSoon = DueStatus(type: RecurrenceType.byTime, isDueSoon: true);
  const overdue = DueStatus(type: RecurrenceType.byTime, isOverdue: true);
  const stale = DueStatus(type: RecurrenceType.byValue, isReadingStale: true);

  final filter = TrackedItem(
    id: 'f',
    name: 'Lõi lọc nước',
    category: ItemCategory.home,
    notes: 'Mã lõi: RO-3, tiệm Đức Phát',
  );
  final bike = TrackedItem(
    id: 'b',
    name: 'Xe máy Wave',
    category: ItemCategory.vehicle,
  );

  test('foldDiacritics strips Vietnamese accents and đ, lowercases', () {
    expect(foldDiacritics('Lõi LỌC Nước'), 'loi loc nuoc');
    expect(foldDiacritics('Đức Phát'), 'duc phat');
    expect(foldDiacritics('ỳýỷỹỵ ÀÁẢÃẠ'), 'yyyyy aaaaa');
    expect(foldDiacritics('RO-3 abc'), 'ro-3 abc');
  });

  test('an empty filter matches everything and is inactive', () {
    const f = ItemFilter();
    expect(f.isActive, isFalse);
    expect(f.matches(filter, ok), isTrue);
    expect(f.matches(bike, overdue), isTrue);
  });

  group('query', () {
    test('matches name without accents or case', () {
      const f = ItemFilter(query: 'LOC nuoc');
      expect(f.isActive, isTrue);
      expect(f.matches(filter, ok), isTrue);
      expect(f.matches(bike, ok), isFalse);
    });

    test('matches notes too', () {
      expect(const ItemFilter(query: 'ro-3').matches(filter, ok), isTrue);
      expect(const ItemFilter(query: 'duc phat').matches(filter, ok), isTrue);
    });

    test('every word must match, in any order', () {
      expect(const ItemFilter(query: 'nuoc loi').matches(filter, ok), isTrue);
      expect(const ItemFilter(query: 'nuoc xe').matches(filter, ok), isFalse);
    });

    test('whitespace-only query matches everything', () {
      const f = ItemFilter(query: '   ');
      expect(f.isActive, isFalse);
      expect(f.matches(bike, ok), isTrue);
    });
  });

  test('categories: empty = any, otherwise must be one of them', () {
    const vehicles = ItemFilter(categories: {ItemCategory.vehicle});
    expect(vehicles.matches(bike, ok), isTrue);
    expect(vehicles.matches(filter, ok), isFalse);

    const both = ItemFilter(
      categories: {ItemCategory.vehicle, ItemCategory.home},
    );
    expect(both.matches(bike, ok), isTrue);
    expect(both.matches(filter, ok), isTrue);
  });

  test('attentionOnly keeps overdue, due-soon and stale-reading items', () {
    const f = ItemFilter(attentionOnly: true);
    expect(f.matches(bike, ok), isFalse);
    expect(f.matches(bike, dueSoon), isTrue);
    expect(f.matches(bike, overdue), isTrue);
    expect(f.matches(bike, stale), isTrue);
  });

  test('all criteria combine with AND', () {
    const f = ItemFilter(
      query: 'wave',
      categories: {ItemCategory.vehicle},
      attentionOnly: true,
    );
    expect(f.matches(bike, overdue), isTrue);
    expect(f.matches(bike, ok), isFalse);
    expect(f.matches(filter, overdue), isFalse);
  });

  test('copyWith keeps unspecified fields', () {
    const f = ItemFilter(query: 'a', attentionOnly: true);
    final g = f.copyWith(categories: {ItemCategory.home});
    expect(g.query, 'a');
    expect(g.attentionOnly, isTrue);
    expect(g.categories, {ItemCategory.home});
  });
}

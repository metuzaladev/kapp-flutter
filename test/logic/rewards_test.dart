import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kapp/core/logic/rewards.dart';
import 'package:kapp/models/explore.dart';

Object? _lookup(Map<String, Object?> table, String key) {
  Object? node = table;
  for (final part in key.split('.')) {
    node = node is Map ? node[part] : null;
  }
  return node;
}

void main() {
  final tables = [
    for (final l in ['et', 'en', 'ru'])
      jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, Object?>,
  ];

  test('maps every server level id, badge and ledger reason to a name in all three languages', () {
    for (final id in RewardLevelId.values) {
      for (final t in tables) {
        expect(_lookup(t, levelNameKey(id)), isA<String>(), reason: levelNameKey(id));
      }
    }
    expect(_lookup(tables[0], levelNameKey(RewardLevelId.parkFriend)), 'Pargisõber');
    for (final id in RewardBadgeId.values) {
      expect(badgeIcon[id], isNotNull);
      for (final t in tables) {
        expect(_lookup(t, badgeNameKey(id)), isA<String>());
      }
    }
    for (final reason in RewardReason.values) {
      expect(reasonIcon[reason], isNotNull);
      for (final t in tables) {
        expect(_lookup(t, reasonTitleKey(reason)), isA<String>());
      }
    }
  });

  test('shows the 0-based server index as "tase 1…"', () {
    expect(levelNumber(0), 1);
    expect(levelNumber(3), 4);
    expect(levelNumber(-1), 1);
  });

  group('streak days', () {
    const lastDays = [
      (date: '2026-09-26', active: true),
      (date: '2026-09-27', active: true),
      (date: '2026-09-28', active: false),
      (date: '2026-09-29', active: true),
      (date: '2026-09-30', active: true),
      (date: '2026-10-01', active: true),
      (date: '2026-10-02', active: false),
    ];

    test('keeps the server order (oldest first) and marks only the last day as today', () {
      final days = streakDays(lastDays, (d) => d.substring(d.length - 2));
      expect(days.map((d) => d.letter), ['26', '27', '28', '29', '30', '01', '02']);
      expect(days.where((d) => d.isToday).map((d) => d.date), ['2026-10-02']);
      expect(days.map((d) => d.active), lastDays.map((d) => d.active));
    });

    test('gives Estonian one-letter weekdays without shifting the calendar day by time zone', () async {
      await initializeDateFormatting('et');
      final letter = weekdayLetterIn('et');
      // 2026-09-28 is a Monday (esmaspäev), 2026-10-04 a Sunday (pühapäev).
      expect(letter('2026-09-28'), 'E');
      expect(letter('2026-10-04'), 'P');
    });
  });

  test('clamps badge progress to 0…1 and fills unlocked badges', () {
    expect(badgeProgress(unlocked: false, progress: 3, target: 10), closeTo(0.3, 1e-9));
    expect(badgeProgress(unlocked: false, progress: 12, target: 10), 1);
    expect(badgeProgress(unlocked: true, progress: 0, target: 10), 1);
    expect(badgeProgress(unlocked: false, progress: 1, target: 0), 0);
  });
}

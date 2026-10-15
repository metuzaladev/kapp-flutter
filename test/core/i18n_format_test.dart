import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/format.dart';
import 'package:kapp/core/i18n/i18n.dart';

import '../helpers.dart';

/// Counted nouns ("6 koera", "3 sõpra pargis", "320 käppa") go through plural keys, never string
/// concatenation. Russian needs one/few/many; Estonian and English one/other.
void main() {
  setUpAll(loadI18n);
  tearDown(() => I18n.instance.setLanguage(Language.et));

  void inLanguage(Language l, void Function() run) {
    I18n.instance.setLanguage(l);
    run();
  }

  test('plural categories', () {
    expect(pluralCategory(Language.et, 1), 'one');
    expect(pluralCategory(Language.et, 2), 'other');
    expect(pluralCategory(Language.ru, 21), 'one');
    expect(pluralCategory(Language.ru, 3), 'few');
    expect(pluralCategory(Language.ru, 11), 'many');
    expect(pluralCategory(Language.ru, 1.5), 'other');
  });

  test('missing params stay visible; missing keys fall back to Estonian, then the key', () {
    expect(interpolate('Tere {{name}} ja {{other}}', {'name': 'Mari'}), 'Tere Mari ja {{other}}');
    expect(tr('no.such.key'), 'no.such.key');
  });

  test('dog counts in Estonian, English and Russian', () {
    inLanguage(Language.et, () {
      expect(dogsLabel(1), '1 koer');
      expect(dogsLabel(6), '6 koera');
    });
    inLanguage(Language.en, () {
      expect(dogsLabel(1), '1 dog');
      expect(dogsLabel(3), '3 dogs');
    });
    inLanguage(Language.ru, () {
      expect(dogsLabel(1), '1 собака');
      expect(dogsLabel(2), '2 собаки');
      expect(dogsLabel(5), '5 собак');
      expect(dogsLabel(11), '11 собак');
      expect(dogsLabel(21), '21 собака');
    });
  });

  test('friends in the park and the Käpad balance', () {
    inLanguage(Language.et, () {
      expect(friendsInParkLabel(1), '1 sõber pargis');
      expect(friendsInParkLabel(3), '3 sõpra pargis');
      expect(tr('points.balance', count: 320), '320 käppa');
    });
    inLanguage(Language.ru, () {
      expect(friendsInParkLabel(5), '5 друзей в парке');
      expect(tr('points.balance', count: 3), '3 лапки');
    });
  });

  test('paw amounts and "2 h tagasi"', () {
    final now = DateTime.parse('2026-10-02T12:00:00Z');
    inLanguage(Language.et, () {
      expect(pawsLabel(1), '1 käpp');
      expect(pawsLabel(15), '15 käppa');
      expect(formatAgo('2026-10-02T10:00:00Z', now: now), '2 h tagasi');
      expect(formatAgo('2026-10-01T12:00:00Z', now: now), '1 päev tagasi');
      expect(formatAgo('2026-10-02T11:59:40Z', now: now), 'just praegu');
    });
    inLanguage(Language.ru, () {
      expect(pawsLabel(25), '25 лапок');
      expect(formatAgo('2026-09-27T12:00:00Z', now: now), '5 дней назад');
    });
  });

  test('lists and planned visits', () {
    inLanguage(Language.ru, () {
      expect(plannedVisitsLabel(3), '3 запланированных визита');
      expect(formatList(['Мари', 'Яан']), 'Мари и Яан');
    });
    inLanguage(Language.en, () => expect(formatList(['Mari', 'Jaan', 'Luna']), 'Mari, Jaan and Luna'));
  });

  test('times use a dot in Estonian, prices drop zero cents', () {
    final evening = DateTime(2026, 10, 2, 17);
    inLanguage(Language.et, () {
      expect(formatTime(evening), '17.00');
      expect(formatPrice(3500).replaceAll(' ', ' '), '35 €');
      expect(formatPrice(1250).replaceAll(' ', ' '), '12,50 €');
    });
    inLanguage(Language.en, () => expect(formatTime(evening), '17:00'));
  });

  test('due dates and ages relative to today', () {
    final now = DateTime(2026, 10, 2);
    inLanguage(Language.et, () {
      expect(dueLabel('2026-10-02', now: now), tr('dates.today'));
      expect(dueLabel('2026-10-03', now: now), tr('dates.tomorrow'));
      expect(isOverdue('2026-10-01', now: now), isTrue);
      expect(ageLabel('2026-10-01', now: now), tr('dates.ageNewborn'));
      expect(ageLabel('2024-09-01', now: now), tr('dates.ageYears', count: 2));
    });
  });
}

import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/dogs.dart';
import '../models/explore.dart';
import 'i18n/i18n.dart';

/// Display formats in the active language (port of lib/format.ts). One place so every screen shows
/// "17.00", "1,2 km" and "täna" the same way. Numbers and dates go through package:intl with the
/// active locale; words that follow a number go through plural keys (Estonian and English one/other,
/// Russian one/few/many), so "1 foto" / "5 fotot" / "5 фото" are always right.

String get _locale => currentLanguage().intlLocale;

String _number(num value, [int maximumFractionDigits = 1]) {
  final f = NumberFormat.decimalPattern(_locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maximumFractionDigits;
  return f.format(value);
}

/// "1,2 km" / "1.2 km" / "1,2 км"
String? formatKm(double? km) => km == null ? null : tr('units.km', params: {'value': _number(km)});

/// "12,5 kg"
String formatKg(double kg) => tr('units.kg', params: {'value': _number(kg)});

/// A whole number with the locale's grouping ("1 200" / "1,200" / "1 200").
String formatNumber(num value) => _number(value, 0);

/// A rating average such as "4,8".
String formatRating(double value) => _number(value);

String _hm(DateTime dt) {
  final text = DateFormat.Hm(_locale).format(dt);
  // "17.00" in Estonian (the Figma copy and the Estonian norm use a dot), "17:00" otherwise.
  return currentLanguage() == Language.et ? text.replaceFirst(':', '.') : text;
}

DateTime _local(String iso) => DateTime.parse(iso).toLocal();

/// A moment in an IANA zone (booking times are the provider's wall clock, Europe/Tallinn).
DateTime _inZone(String iso, String timeZone) {
  try {
    return tz.TZDateTime.from(DateTime.parse(iso), tz.getLocation(timeZone));
  } catch (_) {
    return _local(iso);
  }
}

String formatTime(Object isoOrDate) => _hm(isoOrDate is DateTime ? isoOrDate.toLocal() : _local(isoOrDate as String));

String formatTimeIn(String iso, String timeZone) => _hm(_inZone(iso, timeZone));

/// "teisipäev, 6. oktoober" in the provider's zone — the date on a booking card.
String formatDateIn(String iso, String timeZone) => DateFormat.MMMMEEEEd(_locale).format(_inZone(iso, timeZone));

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// A calendar date ("2026-03-01") as a local date — never a UTC parse that can shift a day.
DateTime localDate(String isoDate) {
  final p = isoDate.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

int _dayDiff(DateTime day, DateTime now) => (_startOfDay(day).difference(_startOfDay(now)).inHours / 24).round();

String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// A slot day chip from a calendar date: "Täna", "Homme" or "R 9. okt" (capitalised: a chip is a
/// standalone label).
String formatDayChip(String isoDate, {DateTime? now}) {
  final day = localDate(isoDate);
  final diff = _dayDiff(day, now ?? DateTime.now());
  final label = diff == 0
      ? tr('dates.today')
      : diff == 1
      ? tr('dates.tomorrow')
      : DateFormat.MMMEd(_locale).format(day);
  return _capitalize(label);
}

/// "35 €" / "€35" / "12,50 €": whole euros without decimals as in Figma, cents only when present.
String formatPrice(int cents) {
  final euros = cents / 100;
  final whole = cents % 100 == 0;
  return NumberFormat.currency(locale: _locale, name: 'EUR', symbol: '€', decimalDigits: whole ? 0 : 2).format(euros);
}

/// Figma "alates 35 €" when the final price depends on the dog, otherwise "12 €".
String priceLabel(int cents, bool isFrom) =>
    isFrom ? tr('units.priceFrom', params: {'price': formatPrice(cents)}) : formatPrice(cents);

/// An hour of the day as a time chip: 17 → "17.00".
String formatHour(int hour) {
  final now = DateTime.now();
  return formatTime(DateTime(now.year, now.month, now.day, hour));
}

String _longWeekdayShortMonth(DateTime d) {
  final pattern = switch (currentLanguage()) {
    Language.et => 'EEEE, d. MMM',
    Language.en => 'EEEE d MMM',
    Language.ru => 'EEEE, d MMM',
  };
  return DateFormat(pattern, _locale).format(d);
}

/// "täna", "homme", "eile" or "reede, 2. okt"
String formatDay(String iso, {DateTime? now}) {
  final d = _local(iso);
  final diff = _dayDiff(d, now ?? DateTime.now());
  if (diff == 0) return tr('dates.today');
  if (diff == 1) return tr('dates.tomorrow');
  if (diff == -1) return tr('dates.yesterday');
  return _longWeekdayShortMonth(d);
}

/// Header date as in Figma Home: "Kolmapäev, 30. september".
String formatToday({DateTime? now}) => _capitalize(DateFormat.MMMMEEEEd(_locale).format(now ?? DateTime.now()));

/// "45 min", "1 h 30 min"
String formatDuration(int minutes) {
  if (minutes < 60) return tr('units.minutes', params: {'value': minutes});
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? tr('units.hours', params: {'value': hours})
      : tr('units.hoursMinutes', params: {'hours': hours, 'minutes': rest});
}

/// Compact for chips: "30 min", "1 h", "1,5 h".
String formatDurationShort(int minutes) => minutes < 60
    ? tr('units.minutes', params: {'value': minutes})
    : tr('units.hours', params: {'value': _number(minutes / 60)});

String reviewsLabel(int count) => tr('counts.reviews', count: count);

/// "1 koer", "3 koera" — Estonian partitive after numbers other than 1; Russian one/few/many.
String dogsLabel(int count) => tr('counts.dogs', count: count);

String friendsInParkLabel(int count) => tr('counts.friendsInPark', count: count);

String photosLabel(int count) => tr('counts.photos', count: count);

String visitsLabel(int count) => tr('counts.visits', count: count);

String plannedVisitsLabel(int count) => tr('counts.plannedVisits', count: count);

/// "Mari", "Mari ja Jaan", "Mari, Jaan ja Luna".
String formatList(List<String> items) {
  if (items.length <= 1) return items.isEmpty ? '' : items.first;
  return tr('common.listAnd', params: {'rest': items.sublist(0, items.length - 1).join(', '), 'last': items.last});
}

/// "isane" / "emane"
String dogSexLabel(DogSex sex) => tr(sex == DogSex.male ? 'dogs.sex.male' : 'dogs.sex.female');

/// "1. märts 2026" / "1 March 2026" / "1 марта 2026 г."
String formatDate(String isoDate) => DateFormat.yMMMMd(_locale).format(localDate(isoDate));

/// A moment as "AAAA-KK-PP" in the device's time zone (default: today).
String localIsoDate([DateTime? now]) {
  final d = now ?? DateTime.now();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)}';
}

int _daysUntil(String isoDate, DateTime now) => _dayDiff(localDate(isoDate), now);

/// Whether a due date has passed — drives the danger colour on health rows.
bool isOverdue(String isoDate, {DateTime? now}) => _daysUntil(isoDate, now ?? DateTime.now()) < 0;

/// "täna", "homme", "5 päeva pärast", "12 päeva hilinenud" for a due date.
String dueLabel(String isoDate, {DateTime? now}) {
  final days = _daysUntil(isoDate, now ?? DateTime.now());
  if (days == 0) return tr('dates.today');
  if (days == 1) return tr('dates.tomorrow');
  if (days > 1) return tr('dates.inDays', count: days);
  return tr('dates.overdue', count: -days);
}

/// "alla kuu", "7 kuud", "1 aasta", "4 aastat" — a dog's age from its birth date.
String ageLabel(String birthDate, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final p = birthDate.split('-').map(int.parse).toList();
  final months = ((at.year - p[0]) * 12 + (at.month - p[1])).clamp(0, 1 << 20);
  if (months >= 12) return tr('dates.ageYears', count: months ~/ 12);
  if (months == 0) return tr('dates.ageNewborn');
  return tr('dates.ageMonths', count: months);
}

/// Figma "Mari ja Luna": the owner's first name with their dogs; just the name without dogs.
String personTitle(String firstName, List<String> dogNames) => dogNames.isEmpty
    ? firstName
    : tr('community.nameWithDogs', params: {'name': firstName, 'dogs': dogNames.join(', ')});

/// "02.10.2026" / "02/10/2026" — a moment's date in the device zone, numeric (safe after any word).
String formatNumericDate(String iso) {
  final pattern = currentLanguage() == Language.en ? 'dd/MM/yyyy' : 'dd.MM.yyyy';
  return DateFormat(pattern, _locale).format(_local(iso));
}

/// The date in "Sõbrad alates …": Estonian uses the numeric date ("02.10.2026", the usual written
/// form after "alates"); Russian/English the long date where the month is declined.
String formatFriendsSince(String iso) =>
    currentLanguage() == Language.et ? formatNumericDate(iso) : DateFormat.yMMMMd(_locale).format(_local(iso));

/// Figma "soovitab · 2 h tagasi". After a week the numeric date.
String formatAgo(String iso, {DateTime? now}) {
  final minutes = (now ?? DateTime.now()).difference(DateTime.parse(iso)).inMinutes;
  if (minutes < 1) return tr('dates.justNow');
  if (minutes < 60) return tr('dates.minutesAgo', count: minutes);
  final hours = minutes ~/ 60;
  if (hours < 24) return tr('dates.hoursAgo', count: hours);
  final days = hours ~/ 24;
  if (days < 7) return tr('dates.daysAgo', count: days);
  return formatNumericDate(iso);
}

/// "150 käppa" / "150 paws" / "150 лап" (plural key, grouped number).
String pawsLabel(int count) => tr('points.paws', count: count, params: {'value': formatNumber(count)});

/// A chat timestamp: the time today, otherwise the day and the time.
String formatMessageTime(String iso, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final sameDay = _startOfDay(_local(iso)) == _startOfDay(at);
  return sameDay ? formatTime(iso) : '${formatDay(iso, now: at)} ${formatTime(iso)}';
}

/// "Kaerahelbe maiused · −15%" or "Broneeringu soodustus · −15%".
String redemptionTitle(Redemption r) => r.product != null
    ? tr('redemptions.productTitle', params: {'name': r.product!.name, 'percent': r.discountPercent})
    : tr('redemptions.bookingTitle', params: {'percent': r.discountPercent});

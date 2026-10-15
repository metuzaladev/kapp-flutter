import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Languages of the app and the API. Estonian is the source language and the fallback: anything
/// unknown (device language, a missing key) ends up in Estonian.
enum Language {
  et('et-EE', 'et'),
  en('en-GB', 'en_GB'),
  ru('ru-RU', 'ru');

  const Language(this.localeTag, this.intlLocale);

  /// BCP 47 tag (en-GB for a 24-hour clock and day-month order, as in Estonia).
  final String localeTag;

  /// Locale name for package:intl formatting.
  final String intlLocale;

  static Language? tryParse(String? value) {
    for (final l in Language.values) {
      if (l.name == value) return l;
    }
    return null;
  }

  /// "ru-RU", "en_GB", "ET" → a supported language by its primary subtag, or null.
  static Language? match(String? tag) {
    final primary = tag?.trim().split(RegExp('[-_]')).first.toLowerCase();
    return tryParse(primary);
  }
}

const Language defaultLanguage = Language.et;

/// i18next plural category for a count (Intl.PluralRules): Estonian and English one/other,
/// Russian one/few/many/other.
String pluralCategory(Language language, num count) {
  final isInt = count == count.truncate();
  switch (language) {
    case Language.et:
    case Language.en:
      return isInt && count.abs() == 1 ? 'one' : 'other';
    case Language.ru:
      if (!isInt) return 'other';
      final n = count.abs().toInt();
      final mod10 = n % 10;
      final mod100 = n % 100;
      if (mod10 == 1 && mod100 != 11) return 'one';
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'few';
      return 'many';
  }
}

final _placeholder = RegExp(r'\{\{\s*(\w+)\s*\}\}');

/// Replaces `{{name}}` placeholders; a missing param stays visible instead of printing "null".
String interpolate(String template, Map<String, Object?> params) {
  return template.replaceAllMapped(_placeholder, (m) {
    final name = m.group(1)!;
    return params.containsKey(name) ? '${params[name]}' : m.group(0)!;
  });
}

/// UI translations (docs/11-tolked-ja-figma.md in the React Native repo), loaded from the same
/// JSON tables the React Native app uses (`assets/i18n/{et,en,ru}.json`) with i18next semantics:
/// nested keys, `{{param}}` placeholders, plural suffixes (`_one`, `_few`, `_many`, `_other`, and
/// `_zero` for a count of 0). API/validation messages come from the shared tables
/// (`assets/i18n/shared.*.json`, exported from `packages/shared`).
class I18n extends ChangeNotifier {
  I18n._();

  static final I18n instance = I18n._();

  final Map<Language, Map<String, Object?>> _app = {};
  final Map<Language, Map<String, Object?>> _shared = {};
  Language _language = defaultLanguage;

  Language get language => _language;

  bool get isLoaded => _app.isNotEmpty;

  /// Loads every table once at start-up (they are bundled, so this is fast) and the date symbols
  /// package:intl needs for the three locales.
  Future<void> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    for (final l in Language.values) {
      _app[l] = jsonDecode(await b.loadString('assets/i18n/${l.name}.json')) as Map<String, Object?>;
      _shared[l] = jsonDecode(await b.loadString('assets/i18n/shared.${l.name}.json')) as Map<String, Object?>;
    }
    for (final l in Language.values) {
      await initializeDateFormatting(l.intlLocale);
    }
  }

  /// Test hook: tables given directly instead of from the asset bundle.
  @visibleForTesting
  void loadTables(Map<Language, Map<String, Object?>> app, [Map<Language, Map<String, Object?>> shared = const {}]) {
    _app
      ..clear()
      ..addAll(app);
    _shared
      ..clear()
      ..addAll(shared);
  }

  void setLanguage(Language language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
  }

  /// The first language in the device's preference list that the app supports, else Estonian.
  static Language deviceLanguage() {
    for (final locale in ui.PlatformDispatcher.instance.locales) {
      final l = Language.match(locale.toLanguageTag()) ?? Language.match(locale.languageCode);
      if (l != null) return l;
    }
    return defaultLanguage;
  }

  /// Translates `key` in the current language, falling back to Estonian and finally to the key.
  String t(String key, {Map<String, Object?> params = const {}, num? count}) {
    final all = count == null ? params : {'count': count, ...params};
    final template = _resolve(_language, key, count) ?? _resolve(defaultLanguage, key, count) ?? key;
    return interpolate(template, all);
  }

  /// Whether a key exists (any plural form) in the current language or the fallback.
  bool exists(String key) =>
      _resolve(_language, key, null) != null ||
      _resolve(_language, key, 1) != null ||
      _resolve(defaultLanguage, key, null) != null;

  /// A message from the shared API/validation tables (`validation.minChars`, `errors.notFound` …).
  String shared(String key, [Map<String, Object?> params = const {}]) {
    final template = (_shared[_language]?[key] ?? _shared[defaultLanguage]?[key]) as String?;
    return interpolate(template ?? key, params);
  }

  bool sharedExists(String key) => _shared[defaultLanguage]?.containsKey(key) ?? false;

  String? _resolve(Language language, String key, num? count) {
    final table = _app[language];
    if (table == null) return null;
    if (count != null) {
      if (count == 0) {
        final zero = _lookup(table, '${key}_zero');
        if (zero != null) return zero;
      }
      final form = _lookup(table, '${key}_${pluralCategory(language, count)}') ?? _lookup(table, '${key}_other');
      if (form != null) return form;
    }
    return _lookup(table, key);
  }

  static String? _lookup(Map<String, Object?> table, String key) {
    Object? node = table;
    for (final part in key.split('.')) {
      if (node is Map<String, Object?>) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node is String ? node : null;
  }
}

/// Global shortcut for code outside widgets (formatters, API errors).
String tr(String key, {Map<String, Object?> params = const {}, num? count}) =>
    I18n.instance.t(key, params: params, count: count);

/// The language currently shown — for formatting, Accept-Language and shared validation texts.
Language currentLanguage() => I18n.instance.language;

/// Rebuilds every widget that translates with `context.t` when the language changes.
class I18nScope extends InheritedNotifier<I18n> {
  I18nScope({super.key, required super.child}) : super(notifier: I18n.instance);
}

extension I18nContext on BuildContext {
  /// Translates and registers the widget for rebuilds on a language change.
  String t(String key, {Map<String, Object?> params = const {}, num? count}) {
    dependOnInheritedWidgetOfExactType<I18nScope>();
    return I18n.instance.t(key, params: params, count: count);
  }

  Language get language {
    dependOnInheritedWidgetOfExactType<I18nScope>();
    return I18n.instance.language;
  }
}

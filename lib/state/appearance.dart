import 'package:flutter/material.dart';

import '../core/storage/preferences.dart';

/// Settings → "Välimus": follow the system, or always light / always dark.
///
/// Default is **light**: the M9 Figma redesign ("03 · Screens") is drawn in light mode, and the dark
/// palette is the secondary theme. Same storage reasoning as the language preference (docs/11).
enum AppearancePreference {
  system,
  light,
  dark;

  static AppearancePreference? tryParse(String? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }

  ThemeMode get themeMode => switch (this) {
    system => ThemeMode.system,
    light => ThemeMode.light,
    dark => ThemeMode.dark,
  };
}

const appearanceStorageKey = 'kapp.appearance';
const defaultAppearance = AppearancePreference.light;

class AppearanceStore extends ValueNotifier<AppearancePreference> {
  AppearanceStore(this._storage) : super(defaultAppearance);

  final PreferenceStorage _storage;

  static final AppearanceStore instance = AppearanceStore(const SharedPreferenceStorage());

  /// Reads the stored choice. Never throws; failure keeps the default (light).
  Future<AppearancePreference> load() async {
    String? stored;
    try {
      stored = await _storage.getItem(appearanceStorageKey);
    } catch (_) {
      // Unreadable storage: keep the default, like the language preference keeps "auto".
    }
    value = AppearancePreference.tryParse(stored) ?? defaultAppearance;
    return value;
  }

  /// Applies immediately, persists best-effort.
  Future<void> set(AppearancePreference next) async {
    value = next;
    try {
      await _storage.setItem(appearanceStorageKey, next.name);
    } catch (_) {
      // Still applies for this session.
    }
  }
}

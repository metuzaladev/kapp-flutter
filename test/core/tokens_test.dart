import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kapp/core/theme/colors.dart';
import 'package:kapp/core/theme/tokens.dart';

Color _hex(Object? v) => Color(int.parse('FF${(v! as String).substring(1)}', radix: 16));

/// The Dart tokens must match `packages/shared/src/tokens.ts` (exported to assets/data/tokens.json).
void main() {
  final json = jsonDecode(File('assets/data/tokens.json').readAsStringSync()) as Map<String, Object?>;

  test('accents match the Figma variables', () {
    final source = json['accents']! as Map<String, Object?>;
    for (final name in AccentName.values) {
      final a = source[name.name]! as Map<String, Object?>;
      final dart = accents[name]!;
      expect(dart.base, _hex(a['base']), reason: name.name);
      expect(dart.soft, _hex(a['soft']));
      expect(dart.onBase, _hex(a['onBase']));
      expect(dart.ink, _hex(a['ink']));
    }
  });

  test('primitives and the type scale match', () {
    final p = json['primitives']! as Map<String, Object?>;
    expect(Primitives.ink, _hex(p['ink']));
    expect(Primitives.gray50, _hex(p['gray50']));
    expect(Primitives.inkDeep, _hex(p['inkDeep']));
    final t = json['typography']! as Map<String, Object?>;
    expect(FigmaType.display.fontSize, ((t['display']! as Map)['fontSize'] as num).toDouble());
    expect(FigmaType.caption.lineHeight, ((t['caption']! as Map)['lineHeight'] as num).toDouble());
  });

  test('light and dark palettes resolve like semanticColors()', () {
    final light = AppColors.resolve(Brightness.light, AccentName.green);
    final dark = AppColors.resolve(Brightness.dark, AccentName.green);
    expect(light.background, Primitives.gray50);
    expect(dark.background, Primitives.inkDeep);
    expect(light.brand, accents[AccentName.green]!.base);
    expect(dark.link, accents[AccentName.green]!.light);
  });
}

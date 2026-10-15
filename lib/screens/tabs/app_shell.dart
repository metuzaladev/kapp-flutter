import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../../components/icon.dart';
import '../../components/legal_consent_gate.dart';
import '../../core/haptics.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../hooks/community.dart';

/// The four tabs (Figma tab bar: Avaleht, Kaart, Teated, Profiil) — the NativeTabs of the React
/// Native app. A translucent bar over the content (the map runs under it), brand-tinted selection,
/// an unread badge on Teated (not drawn at zero).
class AppShell extends HookWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (icon: IconName.house, label: 'tabs.home'),
    (icon: IconName.map, label: 'tabs.map'),
    (icon: IconName.bell, label: 'tabs.notifications'),
    (icon: IconName.user, label: 'tabs.profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unread = useUnreadCount().data ?? 0;
    final bottom = MediaQuery.of(context).padding.bottom;

    return LegalConsentGate(
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.88),
                border: Border(top: BorderSide(color: c.border, width: 0.5)),
              ),
              padding: EdgeInsets.only(bottom: bottom),
              height: IosDimensions.tabBarHeight + bottom,
              child: Row(
                children: [
                  for (final (i, tab) in _tabs.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: shell.currentIndex == i,
                        label: [context.t(tab.label), if (i == 2 && unread > 0) '$unread'].join(', '),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (shell.currentIndex != i) haptic(HapticReason.selection);
                            // A second tap on the current tab returns it to its first screen.
                            shell.goBranch(i, initialLocation: i == shell.currentIndex);
                          },
                          child: _TabItem(
                            icon: tab.icon,
                            label: context.t(tab.label),
                            selected: shell.currentIndex == i,
                            badge: i == 2 && unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, this.badge});
  final IconName icon;
  final String label;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = selected ? c.brand : c.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AppIcon(icon, size: 24, color: color),
            if (badge != null)
              Positioned(
                top: -4,
                right: -10,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(Radii.full)),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: textStyle(TextType.micro, color: context.isDark ? c.background : Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle(TextType.micro, color: color),
        ),
      ],
    );
  }
}

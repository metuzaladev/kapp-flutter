import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'text.dart';

/// Figma component "Background / Paws": 21 paw prints at 9 % opacity in the accent colour, behind
/// every screen. The SVG is generated from the Figma positions; its paws are white so a colour filter
/// applies the accent, which keeps it correct for every Figma "Accent" mode and for light/dark.
/// Fixed behind the content (it does not scroll), and hidden from screen readers.
class PawBackground extends StatelessWidget {
  const PawBackground({super.key});

  static const _opacity = 0.09;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: _opacity,
            child: SvgPicture.asset(
              'assets/images/paw-pattern.svg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              colorFilter: ColorFilter.mode(context.c.brand, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

/// A vertical fade into the background colour (Welcome hero photo fading out, the top of the map).
class Fade extends StatelessWidget {
  const Fade({super.key, this.up = false, required this.height});

  /// Fades towards the top (transparent at the bottom) instead of towards the bottom.
  final bool up;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = context.c.background;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: up ? Alignment.bottomCenter : Alignment.topCenter,
            end: up ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.85), bg],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

/// Screen scaffold matching the Figma "Screen Header": title, subtitle, scrollable stack, the paw
/// background, an optional navigation bar (pushed screens and modals) and pull to refresh.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    this.title,
    this.subtitle,
    this.children = const [],
    this.navBar = false,
    this.navTitle,
    this.actions,
    this.onRefresh,
    this.bottom,
    this.scrollController,
    this.gap = Spacing.three,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  /// A transparent navigation bar with the system back (or close, for modals) button.
  final bool navBar;
  final String? navTitle;
  final List<Widget>? actions;

  /// Pull to refresh — only on screens whose data can change while they are open, not on forms.
  final Future<void> Function()? onRefresh;

  /// Pinned under the scrolling content (e.g. a message composer).
  final Widget? bottom;
  final ScrollController? scrollController;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final content = <Widget>[
      if (title != null) AppText(title!, type: TextType.title, header: true),
      if (subtitle != null) AppText(subtitle!, themeColor: TextColor.muted),
      ...children,
    ];
    Widget scroll = ListView.separated(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Spacing.screen, Spacing.three, Spacing.screen, Spacing.six * 2),
      itemCount: content.length,
      separatorBuilder: (_, _) => SizedBox(height: gap),
      itemBuilder: (_, i) => content[i],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator.adaptive(onRefresh: onRefresh!, color: c.brand, child: scroll);
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: navBar
          ? AppBar(
              title: navTitle == null ? null : Text(navTitle!),
              actions: actions,
              backgroundColor: c.background.withValues(alpha: 0.92),
            )
          : null,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            top: !navBar,
            bottom: false,
            child: Column(
              children: [
                Expanded(child: scroll),
                if (bottom != null) SafeArea(top: false, child: bottom!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs the given refetches and resolves when all have settled (pull to refresh).
Future<void> refreshAll(List<Future<void> Function()> refetches) async {
  await Future.wait(refetches.map((r) => r().catchError((Object _) {})));
}

/// Fire-and-forget helper that keeps lints quiet where a Future is intentionally not awaited.
void fireAndForget(Future<void> future) => unawaited(future);

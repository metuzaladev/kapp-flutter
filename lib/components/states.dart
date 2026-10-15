import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/logic/motion.dart';
import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'button.dart';
import 'icon.dart';
import 'text.dart';

/// Form-level error (e.g. a wrong password). Announced to screen readers when it appears.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(color: context.c.dangerSoft, borderRadius: BorderRadius.circular(Radii.r12)),
        child: AppText(message!, type: TextType.label),
      ),
    );
  }
}

/// A list with nothing in it yet: a soft card with a friendly title, one sentence and an optional
/// action (Figma "Empty State / Meetups": every empty state offers one).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.body, this.actionLabel, this.onAction, this.actionHint});

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? actionHint;

  @override
  Widget build(BuildContext context) {
    return Entering(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(color: context.c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, type: TextType.label),
                  if (body != null) ...[
                    const SizedBox(height: 2),
                    AppText(body!, type: TextType.caption, themeColor: TextColor.muted),
                  ],
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.three),
              AppButton(label: actionLabel!, variant: ButtonVariant.secondary, onPressed: onAction, hint: actionHint),
            ],
          ],
        ),
      ),
    );
  }
}

/// A screen's data could not be loaded and nothing is cached: the server's message (already in the
/// user's language) and "Proovi uuesti" (Figma "Offline State").
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.retrying = false});

  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.three),
      decoration: BoxDecoration(color: context.c.dangerSoft, borderRadius: BorderRadius.circular(Radii.r12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(liveRegion: true, child: AppText(message, type: TextType.label)),
          const SizedBox(height: Spacing.three),
          AppButton(
            label: context.t('common.retry'),
            variant: ButtonVariant.secondary,
            loading: retrying,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for a list: grey rows shaped like the content, so the layout does not jump
/// when data arrives. The rows pulse gently; with Reduce Motion they stay still. Screen readers hear
/// one element, "Laen…".
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 3, this.rowHeight = 64});
  final int rows;
  final double rowHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: context.t('common.loading'),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Opacity(
            opacity: skeletonOpacityTo - (skeletonOpacityTo - skeletonOpacityFrom) * _pulse.value,
            child: Column(
              children: [
                for (var i = 0; i < widget.rows; i++) ...[
                  if (i > 0) const SizedBox(height: Spacing.three),
                  Container(
                    constraints: BoxConstraints(minHeight: widget.rowHeight),
                    padding: const EdgeInsets.all(Spacing.three),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.r16),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(widthFactor: 0.55, child: _line(c.soft)),
                        const SizedBox(height: Spacing.two),
                        FractionallySizedBox(widthFactor: 0.35, child: _line(c.soft)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(Color color) => Container(
    height: 12,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.full)),
  );
}

/// Content that appears when its data arrives: fades in and rises 12 pt, like iOS lists settling.
/// Runs once on mount, so refetches do not replay it. With Reduce Motion it is rendered in place.
class Entering extends StatefulWidget {
  const Entering({super.key, required this.child, this.index = 0});
  final Widget child;

  /// Position in a list: rows fade in one after another (capped, see motion.dart).
  final int index;

  @override
  State<Entering> createState() => _EnteringState();
}

class _EnteringState extends State<Entering> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: MotionDurations.standard);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      Future<void>.delayed(staggerDelay(widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Figma "Info Card" (4:36): soft accent card, heading + muted body; optional trailing content.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, this.body, this.child});
  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.c.soft, borderRadius: BorderRadius.circular(Radii.r16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(title, type: TextType.heading),
                if (body != null) ...[const SizedBox(height: Spacing.two), AppText(body!, themeColor: TextColor.muted)],
              ],
            ),
          ),
          if (child != null) ...[const SizedBox(height: Spacing.three), child!],
        ],
      ),
    );
  }
}

/// Figma onboarding / permission benefit row: a 44 pt soft icon tile, a bold title and a muted line.
class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.icon, required this.title, required this.body});
  final IconName icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: '$title, $body',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: AppIcon(icon, size: 22, color: c.brand),
          ),
          const SizedBox(width: Spacing.three),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(title, type: TextType.label),
                const SizedBox(height: 2),
                AppText(body, type: TextType.caption, themeColor: TextColor.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma "või e-postiga": a hairline with a short caption in the middle.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 0.5, color: context.c.border));
    return Row(
      children: [
        line,
        const SizedBox(width: 12),
        AppText(label, type: TextType.caption, themeColor: TextColor.muted),
        const SizedBox(width: 12),
        line,
      ],
    );
  }
}

/// A settings row with a switch (Figma "Toggle Row"); at least 56 pt high.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    this.disabled = false,
    required this.onChanged,
  });
  final String label;
  final String? hint;
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(Spacing.three),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.r16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(label, type: TextType.label),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    AppText(hint!, type: TextType.caption, themeColor: TextColor.muted),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.three),
            Switch.adaptive(value: value, onChanged: disabled ? null : onChanged, activeTrackColor: c.brand),
          ],
        ),
      ),
    );
  }
}

/// Figma "Progress / Reward" (58:134): a rounded track with a fill. Decorative unless `label` is set.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.track,
    required this.fill,
    this.height = 10,
    this.label,
  });
  final double value;
  final Color track;
  final Color fill;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(color: fill),
        ),
      ),
    );
    if (label == null) return ExcludeSemantics(child: bar);
    return Semantics(
      label: label,
      value: '${(v * 100).round()} %',
      child: ExcludeSemantics(child: bar),
    );
  }
}

/// The "it worked" moment (booking confirmed, check-in): a brand-coloured check that pops in with
/// one soft overshoot. Decorative; static with Reduce Motion. The caller plays the success haptic.
class SuccessMark extends StatelessWidget {
  const SuccessMark({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mark = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: AppIcon(IconName.check, size: 32, color: c.onBrand),
    );
    if (MediaQuery.of(context).disableAnimations) return ExcludeSemantics(child: mark);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MotionDurations.emphasized,
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: mark,
      ),
    );
  }
}

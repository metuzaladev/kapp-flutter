/// Motion tokens (docs/14-animatsioonid-ja-ligipaasetavus.md): brief (under 400 ms), purposeful and
/// never blocking input (Apple HIG "Motion").
class MotionDurations {
  const MotionDurations._();

  /// Colour or opacity change of a control (chip selected).
  static const quick = Duration(milliseconds: 150);

  /// Content entering a screen.
  static const standard = Duration(milliseconds: 250);

  /// A success mark — the one moment that may draw attention.
  static const emphasized = Duration(milliseconds: 350);
}

/// Delay between consecutive list rows entering.
const staggerMs = 40;

/// Rows after this index enter together: a long list must not take seconds to appear.
const maxStaggeredRows = 6;

/// Scale of a pressed row or button: a hint of depth, not a bounce.
const pressScale = 0.97;

/// Opacity range of a loading skeleton's pulse.
const skeletonOpacityFrom = 0.45;
const skeletonOpacityTo = 0.9;

/// Delay for the row at `index` in a staggered list; invalid indexes get none.
Duration staggerDelay(int index) => index <= 0
    ? Duration.zero
    : Duration(milliseconds: (index > maxStaggeredRows ? maxStaggeredRows : index) * staggerMs);

/// Zero when the user asked the system to reduce motion (WCAG 2.3.3, HIG "Reduce Motion").
Duration motionDuration(Duration duration, {required bool reduceMotion}) =>
    reduceMotion || duration.isNegative ? Duration.zero : duration;

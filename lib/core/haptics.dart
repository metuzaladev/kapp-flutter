import 'package:flutter/services.dart';

/// The only place that plays haptics (docs/14-animatsioonid-ja-ligipaasetavus.md#haptika).
///
/// Screens call a reason, not a pattern, so "success" always feels the same and a reviewer can see
/// every kind of call site in one table. Flutter's engine exposes impact and selection feedback; the
/// iOS notification patterns of the React Native app map to the closest impact:
///
/// | Reason      | Pattern         | Call sites                                              |
/// |-------------|-----------------|---------------------------------------------------------|
/// | `selection` | selectionClick  | Chips, segmented scopes, rating stars, favourite toggle |
/// | `success`   | mediumImpact    | Check-in, booking confirmed, review saved               |
/// | `warning`   | heavyImpact     | Just before a destructive confirmation                  |
/// | `error`     | heavyImpact     | A submit the server rejected                            |
///
/// Haptics are feedback, never information: everything they signal is also visible and announced.
enum HapticReason { selection, success, warning, error }

void haptic(HapticReason reason) {
  try {
    switch (reason) {
      case HapticReason.selection:
        HapticFeedback.selectionClick();
      case HapticReason.success:
        HapticFeedback.mediumImpact();
      case HapticReason.warning:
      case HapticReason.error:
        HapticFeedback.heavyImpact();
    }
  } catch (_) {
    // A device without haptics: the action itself has already happened.
  }
}

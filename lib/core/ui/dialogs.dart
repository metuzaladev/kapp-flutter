import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../i18n/i18n.dart';

enum AlertStyle { normal, cancel, destructive }

class AlertAction {
  const AlertAction(this.label, {this.style = AlertStyle.normal, this.onPressed});
  final String label;
  final AlertStyle style;
  final VoidCallback? onPressed;
}

/// The React Native `Alert.alert`: a system alert with buttons (Cupertino style on both platforms,
/// matching the iOS-first design). Each button closes the alert before running its action.
Future<void> showAlert(BuildContext context, String title, {String? message, List<AlertAction>? actions}) {
  final list = actions ?? [AlertAction(tr('common.ok'))];
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        for (final a in list)
          CupertinoDialogAction(
            isDefaultAction: a.style == AlertStyle.cancel,
            isDestructiveAction: a.style == AlertStyle.destructive,
            onPressed: () {
              Navigator.of(ctx).pop();
              a.onPressed?.call();
            },
            child: Text(a.label),
          ),
      ],
    ),
  );
}

/// A menu of actions (the "…" menus): iOS action sheet with a separate cancel button.
Future<void> showActionMenu(BuildContext context, {String? title, required List<AlertAction> actions}) {
  final cancel = actions.where((a) => a.style == AlertStyle.cancel).firstOrNull;
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      actions: [
        for (final a in actions.where((a) => a.style != AlertStyle.cancel))
          CupertinoActionSheetAction(
            isDestructiveAction: a.style == AlertStyle.destructive,
            onPressed: () {
              Navigator.of(ctx).pop();
              a.onPressed?.call();
            },
            child: Text(a.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () {
          Navigator.of(ctx).pop();
          cancel?.onPressed?.call();
        },
        child: Text(cancel?.label ?? tr('common.cancel')),
      ),
    ),
  );
}

/// A short confirmation that does not block (Android `ToastAndroid`-like), announced to screen readers.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Reads a message aloud with VoiceOver / TalkBack (`AccessibilityInfo.announceForAccessibility`).
void announce(BuildContext context, String message) {
  SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
}

import 'package:flutter/foundation.dart';

/// A one-time message shown on the signed-out screens after the session ended on purpose (M10:
/// "Sinu konto on kustutatud"). The router swaps to Welcome by itself when the session goes away,
/// so the screen that ended it leaves a notice here instead. In memory only.
enum SessionNotice { accountDeleted }

final ValueNotifier<SessionNotice?> sessionNotice = ValueNotifier(null);

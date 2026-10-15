import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/community.dart';
import '../models/json.dart';
import 'auth/auth_client.dart';
import 'config.dart';

/// The app's single Socket.IO connection (docs/12-kogukond.md). Server → client only: new messages
/// and notifications. Everything else (sending, marking read) goes through the REST API.
///
/// When the socket is down the screens fall back to polling (an open conversation refetches every
/// 15 s), so a broken realtime link only makes updates slower, never lost.
const realtimePath = '/api/v1/realtime';

final ValueNotifier<bool> realtimeConnected = ValueNotifier(false);
io.Socket? _socket;

/// Connects with the Better Auth session cookie (header and handshake payload, see the API gateway).
Future<void> connectRealtime({
  required void Function(Message message) onMessage,
  required void Function() onNotification,
}) async {
  disconnectRealtime();
  final cookie = await AuthClient.instance.cookieHeader();
  if (cookie.isEmpty) return;
  final s = io.io(
    apiOrigin,
    io.OptionBuilder()
        .setPath(realtimePath)
        // WebSocket transport directly (long-polling would need a cookie jar).
        .setTransports(['websocket'])
        .setExtraHeaders({'cookie': cookie})
        .setAuth({'cookie': cookie})
        .setReconnectionDelayMax(30000)
        .disableAutoConnect()
        .build(),
  );
  s.onConnect((_) => realtimeConnected.value = true);
  s.onDisconnect((_) => realtimeConnected.value = false);
  s.onConnectError((_) => realtimeConnected.value = false);
  s.on('message:new', (data) {
    if (data is Map) onMessage(Message.fromJson(Json.from(data)));
  });
  s.on('notification:new', (_) => onNotification());
  s.connect();
  _socket = s;
}

void disconnectRealtime() {
  _socket?.clearListeners();
  _socket?.dispose();
  _socket = null;
  realtimeConnected.value = false;
}

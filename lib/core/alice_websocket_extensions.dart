import 'dart:io';

import 'package:flutter_alice/alice.dart';
import 'package:flutter_alice/core/alice_websocket_adapter.dart';

extension AliceWebSocketExtension on Future<WebSocket> {
  /// Connects to [url] via [WebSocket.connect] and wraps the socket so that
  /// Alice intercepts all frames.
  ///
  /// ```dart
  /// import 'package:flutter_alice/core/alice_websocket_extensions.dart';
  ///
  /// final ws = await WebSocket.connect('wss://echo.example.com')
  ///     .interceptWithAlice(alice, 'wss://echo.example.com');
  /// ws.listen(onData: (msg) => print('received: $msg'));
  /// ws.add('hello');
  /// ```
  Future<AliceWebSocketProxy> interceptWithAlice(
    Alice alice,
    String url,
  ) async {
    final socket = await this;
    return alice.wrapWebSocket(socket, url);
  }
}

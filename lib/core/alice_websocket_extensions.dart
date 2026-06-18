import 'dart:io';

import 'package:flutter_alice/alice.dart';
import 'package:flutter_alice/core/alice_websocket_adapter.dart';
import 'package:web_socket_channel/io.dart';

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

extension AliceIOWebSocketChannelExtension on IOWebSocketChannel {
  /// Wraps this [IOWebSocketChannel] so that Alice intercepts all frames.
  ///
  /// Awaits the WebSocket handshake before registering the call — use this
  /// immediately after [IOWebSocketChannel.connect], before subscribing to
  /// [stream].
  ///
  /// ```dart
  /// import 'package:flutter_alice/core/alice_websocket_extensions.dart';
  ///
  /// final proxy = await IOWebSocketChannel.connect(url, headers: headers)
  ///     .interceptWithAlice(alice, url);
  /// proxy.stream.listen((msg) => print('received: $msg'));
  /// proxy.sink.add('hello');
  /// ```
  Future<AliceWebSocketChannelProxy> interceptWithAlice(
    Alice alice,
    String url,
  ) {
    return alice.wrapWebSocketChannel(this, url);
  }
}

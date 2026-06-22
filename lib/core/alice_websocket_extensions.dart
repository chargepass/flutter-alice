import 'dart:io';

import 'package:flutter_alice/alice.dart';
import 'package:flutter_alice/core/alice_websocket_adapter.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  /// Returns synchronously — the proxy is created before the WebSocket
  /// handshake completes, so callers can await
  /// [AliceWebSocketChannelProxy.ready] themselves. The returned proxy
  /// implements [WebSocketChannel], so it can be assigned to a
  /// `WebSocketChannel?` field directly.
  ///
  /// ```dart
  /// import 'package:flutter_alice/core/alice_websocket_extensions.dart';
  ///
  /// final proxy = IOWebSocketChannel.connect(url, headers: headers)
  ///     .interceptWithAlice(alice, url);
  /// await proxy.ready;
  /// proxy.stream.listen((msg) => print('received: $msg'));
  /// proxy.sink.add('hello');
  /// ```
  AliceWebSocketChannelProxy interceptWithAlice(
    Alice alice,
    String url,
  ) {
    return alice.wrapWebSocketChannelSync(this, url);
  }
}

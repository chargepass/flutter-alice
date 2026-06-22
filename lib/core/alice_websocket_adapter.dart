import 'dart:async';
import 'dart:io';

import 'package:flutter_alice/core/alice_core.dart';
import 'package:flutter_alice/model/alice_http_call.dart';
import 'package:flutter_alice/model/alice_http_request.dart';
import 'package:flutter_alice/model/alice_http_response.dart';
import 'package:flutter_alice/model/alice_ws_message.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wraps a [WebSocket] and records all sent/received messages in Alice.
///
/// Usage:
/// ```dart
/// final raw = await WebSocket.connect('wss://echo.example.com');
/// final ws  = alice.wrapWebSocket(raw, 'wss://echo.example.com');
/// ws.listen(onData: (msg) { /* handle incoming */ });
/// ws.add('hello');
/// ```
class AliceWebSocketAdapter {
  final AliceCore _aliceCore;

  AliceWebSocketAdapter(this._aliceCore);

  /// Wraps an [IOWebSocketChannel] and returns the proxy synchronously, without
  /// awaiting the WebSocket handshake.
  ///
  /// The returned [AliceWebSocketChannelProxy] implements [WebSocketChannel],
  /// so callers can await [AliceWebSocketChannelProxy.ready] themselves once the
  /// proxy is created.
  ///
  /// ```dart
  /// final channel = IOWebSocketChannel.connect(url, headers: headers);
  /// final proxy   = alice.wrapWebSocketChannelSync(channel, url);
  /// await proxy.ready;
  /// proxy.stream.listen((msg) { /* handle incoming */ });
  /// proxy.sink.add('hello');
  /// ```
  AliceWebSocketChannelProxy wrapChannelSync(
    IOWebSocketChannel channel,
    String url,
  ) {
    final uri = Uri.parse(url);
    final callId = channel.hashCode ^ DateTime.now().millisecondsSinceEpoch;

    final call = AliceHttpCall(callId)
      ..isWebSocket = true
      ..client = 'WebSocket (web_socket_channel)'
      ..method = 'WS'
      ..uri = url
      ..server = uri.host
      ..endpoint = uri.path.isEmpty ? '/' : uri.path
      ..secure = uri.scheme == 'wss'
      ..loading = false;

    final handshakeRequest = AliceHttpRequest()
      ..time = DateTime.now()
      ..headers = {'upgrade': 'websocket'}
      ..body = ''
      ..size = 0;

    final handshakeResponse = AliceHttpResponse()
      ..status = 101
      ..body = ''
      ..size = 0
      ..time = DateTime.now()
      ..headers = {'upgrade': 'websocket'};

    call.request = handshakeRequest;
    call.response = handshakeResponse;

    _aliceCore.addCall(call);
    return AliceWebSocketChannelProxy(channel, call, _aliceCore);
  }

  /// Wraps [socket] so that all sent/received frames are captured by Alice.
  /// Returns a thin [AliceWebSocketProxy] that delegates to the original socket.
  AliceWebSocketProxy wrap(WebSocket socket, String url) {
    final uri = Uri.parse(url);
    final callId = socket.hashCode ^ DateTime.now().millisecondsSinceEpoch;

    final call = AliceHttpCall(callId)
      ..isWebSocket = true
      ..client = 'WebSocket (dart:io)'
      ..method = 'WS'
      ..uri = url
      ..server = uri.host
      ..endpoint = uri.path.isEmpty ? '/' : uri.path
      ..secure = uri.scheme == 'wss'
      ..loading = false;

    final handshakeRequest = AliceHttpRequest()
      ..time = DateTime.now()
      ..headers = {'upgrade': 'websocket'}
      ..body = ''
      ..size = 0;

    final handshakeResponse = AliceHttpResponse()
      ..status = 101
      ..body = ''
      ..size = 0
      ..time = DateTime.now()
      ..headers = {'upgrade': 'websocket'};

    call.request = handshakeRequest;
    call.response = handshakeResponse;

    _aliceCore.addCall(call);
    return AliceWebSocketProxy(socket, call, _aliceCore);
  }
}

/// A thin proxy around [WebSocket] that intercepts [add]/[addUtf8Text]/[close]
/// and notifies Alice about each message.
class AliceWebSocketProxy implements StreamSink<dynamic> {
  final WebSocket _socket;
  final AliceHttpCall _call;
  final AliceCore _aliceCore;

  AliceWebSocketProxy(this._socket, this._call, this._aliceCore);

  // --- outbound helpers ---

  void _recordSent(dynamic data) {
    _call.webSocketMessages.add(AliceWebSocketMessage(
      data: data,
      direction: AliceWebSocketMessageDirection.sent,
      time: DateTime.now(),
    ));
    _call.request!.size += _sizeOf(data);
    _aliceCore.callsSubject.add([..._aliceCore.callsSubject.value]);
  }

  int _sizeOf(dynamic data) {
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    return 0;
  }

  /// Send data (text or binary) and record the outbound message in Alice.
  void add(dynamic data) {
    _socket.add(data);
    _recordSent(data);
  }

  /// Close the connection.
  @override
  Future close() {
    _call.loading = false;
    return _socket.close();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _socket.addStream(stream);

  @override
  Future get done => _socket.done;

  // --- inbound ---

  /// Listen to incoming messages. All received messages are recorded in Alice.
  StreamSubscription listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _socket.listen(
      (event) {
        _call.webSocketMessages.add(AliceWebSocketMessage(
          data: event,
          direction: AliceWebSocketMessageDirection.received,
          time: DateTime.now(),
        ));
        _call.response!.size += _sizeOf(event);
        _aliceCore.callsSubject.add([..._aliceCore.callsSubject.value]);
        onData?.call(event);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// The underlying [WebSocket] in case you need direct access.
  WebSocket get socket => _socket;

  int get readyState => _socket.readyState;
}

/// A thin proxy around [IOWebSocketChannel] that intercepts all sent/received
/// messages and records them in Alice.
///
/// Implements [WebSocketChannel] so it can be used anywhere a
/// [WebSocketChannel] is expected. Use [stream] to listen for incoming messages
/// and [sink] to send outbound messages — mirroring the standard
/// [WebSocketChannel] API.
class AliceWebSocketChannelProxy with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final IOWebSocketChannel _channel;
  final AliceHttpCall _call;
  final AliceCore _aliceCore;

  AliceWebSocketChannelProxy(this._channel, this._call, this._aliceCore);

  // --- inbound ---

  /// A [Stream] of incoming messages.  Each received message is recorded in
  /// Alice before being forwarded to the subscriber.
  @override
  late final Stream<dynamic> stream = _channel.stream.map((event) {
    _call.webSocketMessages.add(AliceWebSocketMessage(
      data: event,
      direction: AliceWebSocketMessageDirection.received,
      time: DateTime.now(),
    ));
    _call.response!.size += _sizeOf(event);
    _aliceCore.callsSubject.add([..._aliceCore.callsSubject.value]);
    return event;
  });

  // --- outbound ---

  /// A [WebSocketSink] for sending messages.  Each outbound message is
  /// recorded in Alice before being forwarded to the underlying channel.
  @override
  late final WebSocketSink sink = _AliceWebSocketSink(_channel.sink, _onSent);

  void _onSent(dynamic data) {
    _call.webSocketMessages.add(AliceWebSocketMessage(
      data: data,
      direction: AliceWebSocketMessageDirection.sent,
      time: DateTime.now(),
    ));
    _call.request!.size += _sizeOf(data);
    _aliceCore.callsSubject.add([..._aliceCore.callsSubject.value]);
  }

  int _sizeOf(dynamic data) {
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    return 0;
  }

  /// Completes when the WebSocket handshake succeeds, or throws on failure.
  /// Delegates to the underlying [IOWebSocketChannel.ready].
  @override
  Future<void> get ready => _channel.ready;

  /// The subprotocol selected by the server, or `null` if none was negotiated.
  /// Delegates to the underlying [IOWebSocketChannel.protocol].
  @override
  String? get protocol => _channel.protocol;

  /// The close code set when the connection is closed, or `null` if it is still
  /// open. Delegates to the underlying [IOWebSocketChannel.closeCode].
  @override
  int? get closeCode => _channel.closeCode;

  /// The close reason set when the connection is closed, or `null` if it is
  /// still open. Delegates to the underlying [IOWebSocketChannel.closeReason].
  @override
  String? get closeReason => _channel.closeReason;

  /// The underlying [IOWebSocketChannel] in case direct access is needed.
  IOWebSocketChannel get channel => _channel;
}

/// Internal [WebSocketSink] wrapper that calls [_onAdd] before forwarding
/// each message to the real sink.
class _AliceWebSocketSink implements WebSocketSink {
  final WebSocketSink _inner;
  final void Function(dynamic) _onAdd;

  _AliceWebSocketSink(this._inner, this._onAdd);

  @override
  void add(dynamic data) {
    _onAdd(data);
    _inner.add(data);
  }

  @override
  Future close([int? closeCode, String? closeReason]) =>
      _inner.close(closeCode, closeReason);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _inner.addStream(stream);

  @override
  Future get done => _inner.done;
}

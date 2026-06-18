import 'dart:async';
import 'dart:io';

import 'package:flutter_alice/core/alice_core.dart';
import 'package:flutter_alice/model/alice_http_call.dart';
import 'package:flutter_alice/model/alice_http_request.dart';
import 'package:flutter_alice/model/alice_http_response.dart';
import 'package:flutter_alice/model/alice_ws_message.dart';

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

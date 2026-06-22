import 'dart:io';

// import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// import 'package:flutter_alice/core/alice_chopper_response_interceptor.dart';
import 'package:flutter_alice/core/alice_core.dart';
import 'package:flutter_alice/core/alice_dio_interceptor.dart';
import 'package:flutter_alice/core/alice_http_adapter.dart';
import 'package:flutter_alice/core/alice_http_client_adapter.dart';
import 'package:flutter_alice/core/alice_websocket_adapter.dart';
import 'package:flutter_alice/model/alice_http_call.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Alice {
  /// Should user be notified with notification if there's new request catched
  /// by Alice
  final bool showNotification;

  /// Should inspector be opened on device shake (works only with physical
  /// with sensors)
  final bool showInspectorOnShake;

  /// Should inspector use dark theme
  final bool darkTheme;

  /// Icon url for notification
  final String notificationIcon;

  GlobalKey<NavigatorState>? _navigatorKey;
  late AliceCore _aliceCore;
  late AliceHttpClientAdapter _httpClientAdapter;
  late AliceHttpAdapter _httpAdapter;
  late AliceWebSocketAdapter _webSocketAdapter;

  /// Creates alice instance.
  Alice(
      {GlobalKey<NavigatorState>? navigatorKey,
      this.showNotification = true,
      this.showInspectorOnShake = false,
      this.darkTheme = false,
      this.notificationIcon = "@mipmap/ic_launcher"}) {
    _navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();
    _aliceCore = AliceCore(
      _navigatorKey,
      showNotification,
      showInspectorOnShake,
      darkTheme,
      notificationIcon,
    );
    _httpClientAdapter = AliceHttpClientAdapter(_aliceCore);
    _httpAdapter = AliceHttpAdapter(_aliceCore);
    _webSocketAdapter = AliceWebSocketAdapter(_aliceCore);
  }

  /// Set custom navigation key. This will help if there's route library.
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _aliceCore.setNavigatorKey(navigatorKey);
  }

  /// Get currently used navigation key
  GlobalKey<NavigatorState>? getNavigatorKey() {
    return _navigatorKey;
  }

  /// Get Dio interceptor which should be applied to Dio instance.
  AliceDioInterceptor getDioInterceptor() {
    return AliceDioInterceptor(_aliceCore);
  }

  /// Handle request from HttpClient
  void onHttpClientRequest(HttpClientRequest request, {dynamic body}) {
    _httpClientAdapter.onRequest(request, body: body);
  }

  /// Handle response from HttpClient
  void onHttpClientResponse(
      HttpClientResponse response, HttpClientRequest request,
      {dynamic body}) {
    _httpClientAdapter.onResponse(response, request, body: body);
  }

  /// Handle both request and response from http package
  void onHttpResponse(http.Response response, {dynamic body}) {
    _httpAdapter.onResponse(response, body: body);
  }

  /// Opens Http calls inspector. This will navigate user to the new fullscreen
  /// page where all listened http calls can be viewed.
  void showInspector() {
    _aliceCore.navigateToCallListScreen();
  }

  // /// Get chopper interceptor. This should be added to Chopper instance.
  // List<ResponseInterceptor> getChopperInterceptor() {
  //   return [AliceChopperInterceptor(_aliceCore)];
  // }

  /// Handle generic http call. Can be used to any http client.
  void addHttpCall(AliceHttpCall aliceHttpCall) {
    assert(aliceHttpCall.request != null, "Http call request can't be null");
    assert(aliceHttpCall.response != null, "Http call response can't be null");
    _aliceCore.addCall(aliceHttpCall);
  }

  /// Wraps an already-connected [WebSocket] so that all sent and received
  /// frames are captured and displayed in the Alice inspector.
  ///
  /// ```dart
  /// final raw = await WebSocket.connect('wss://echo.example.com');
  /// final ws  = alice.wrapWebSocket(raw, 'wss://echo.example.com');
  /// ws.listen(onData: (msg) => print(msg));
  /// ws.add('hello');
  /// ```
  AliceWebSocketProxy wrapWebSocket(WebSocket socket, String url) {
    return _webSocketAdapter.wrap(socket, url);
  }

  /// Wraps an [IOWebSocketChannel] so that all sent and received frames are
  /// captured and displayed in the Alice inspector, returning the proxy
  /// synchronously without awaiting the WebSocket handshake.
  ///
  /// The returned [AliceWebSocketChannelProxy] implements [WebSocketChannel],
  /// so it can be assigned to a `WebSocketChannel?` field and awaited via
  /// [AliceWebSocketChannelProxy.ready].
  ///
  /// ```dart
  /// final channel = IOWebSocketChannel.connect(url, headers: headers);
  /// final proxy   = alice.wrapWebSocketChannelSync(channel, url);
  /// await proxy.ready;
  /// proxy.stream.listen((msg) => print(msg));
  /// proxy.sink.add('hello');
  /// ```
  AliceWebSocketChannelProxy wrapWebSocketChannelSync(
    IOWebSocketChannel channel,
    String url,
  ) {
    return _webSocketAdapter.wrapChannelSync(channel, url);
  }

  /// Returns the [AliceWebSocketAdapter] for advanced usage.
  AliceWebSocketAdapter getWebSocketAdapter() => _webSocketAdapter;
}

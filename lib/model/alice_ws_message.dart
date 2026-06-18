enum AliceWebSocketMessageDirection { sent, received }

class AliceWebSocketMessage {
  final dynamic data;
  final AliceWebSocketMessageDirection direction;
  final DateTime time;

  AliceWebSocketMessage({
    required this.data,
    required this.direction,
    required this.time,
  });

  bool get isSent => direction == AliceWebSocketMessageDirection.sent;

  int get size {
    if (data is String) return (data as String).length;
    if (data is List<int>) return (data as List<int>).length;
    return 0;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_alice/model/alice_http_call.dart';
import 'package:flutter_alice/model/alice_ws_message.dart';
import 'package:flutter_alice/ui/utils/alice_constants.dart';

class AliceCallWsWidget extends StatelessWidget {
  final AliceHttpCall call;

  const AliceCallWsWidget(this.call);

  @override
  Widget build(BuildContext context) {
    final messages = call.webSocketMessages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No WebSocket messages yet',
          style: TextStyle(fontSize: 16, color: AliceConstants.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageTile(context, messages[index], index),
    );
  }

  Widget _buildMessageTile(
      BuildContext context, AliceWebSocketMessage msg, int index) {
    final isSent = msg.isSent;
    final color = isSent ? AliceConstants.orange : AliceConstants.green;
    final icon = isSent ? Icons.arrow_upward : Icons.arrow_downward;
    final label = isSent ? 'SENT' : 'RCVD';
    final dataStr = msg.data is String
        ? msg.data as String
        : '[binary ${msg.size} bytes]';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 18),
        title: Text(
          dataStr,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        subtitle: Text(
          '${msg.time.hour.toString().padLeft(2, '0')}:'
          '${msg.time.minute.toString().padLeft(2, '0')}:'
          '${msg.time.second.toString().padLeft(2, '0')}.'
          '${msg.time.millisecond.toString().padLeft(3, '0')}  '
          '${msg.size} bytes',
          style: TextStyle(fontSize: 11, color: AliceConstants.grey),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

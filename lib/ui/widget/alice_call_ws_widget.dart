import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      return SafeArea(
        child: Center(
          child: Text(
            'No WebSocket messages yet',
            style: TextStyle(fontSize: 16, color: AliceConstants.grey),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) =>
            _WsMessageTile(msg: messages[index], index: index),
      ),
    );
  }
}

class _WsMessageTile extends StatefulWidget {
  final AliceWebSocketMessage msg;
  final int index;

  const _WsMessageTile({required this.msg, required this.index});

  @override
  State<_WsMessageTile> createState() => _WsMessageTileState();
}

class _WsMessageTileState extends State<_WsMessageTile> {
  bool _expanded = false;

  AliceWebSocketMessage get msg => widget.msg;

  String get _dataStr => msg.data is String
      ? msg.data as String
      : '[binary ${msg.size} bytes]';

  String get _timeStr =>
      '${msg.time.hour.toString().padLeft(2, '0')}:'
      '${msg.time.minute.toString().padLeft(2, '0')}:'
      '${msg.time.second.toString().padLeft(2, '0')}.'
      '${msg.time.millisecond.toString().padLeft(3, '0')}';

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _dataStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSent = msg.isSent;
    final color = isSent ? AliceConstants.orange : AliceConstants.green;
    final icon = isSent ? Icons.arrow_upward : Icons.arrow_downward;
    final label = isSent ? 'SENT' : 'RCVD';
    final isLong = _dataStr.length > 120;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_timeStr  •  ${msg.size} bytes',
                  style: TextStyle(fontSize: 11, color: AliceConstants.grey),
                ),
                const Spacer(),
                // Copy button
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: AliceConstants.grey),
                  ),
                ),
                // Expand/collapse toggle (only if long)
                if (isLong) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: AliceConstants.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Message body
          GestureDetector(
            onTap: isLong
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                _dataStr,
                maxLines: _expanded ? null : 4,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
          ),
          if (isLong && !_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'Tap to expand',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

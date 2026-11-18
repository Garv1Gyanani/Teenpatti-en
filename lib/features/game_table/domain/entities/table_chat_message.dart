/// A chat message or quick reaction sent at a Teen Patti table.
class TableChatMessage {
  const TableChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.isLocal = false,
    this.isQuickReaction = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final DateTime timestamp;
  final bool isLocal;
  final bool isQuickReaction;
}

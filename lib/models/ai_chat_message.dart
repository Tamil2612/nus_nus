enum AiChatMessageType { text, groupPicker, memberHint, resultPreview }

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;
  final AiChatMessageType type;
  final dynamic metadata;

  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.type,
    this.imagePath,
    this.metadata,
  }) : timestamp = DateTime.now();
}

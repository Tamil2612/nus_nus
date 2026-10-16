import 'package:cloud_firestore/cloud_firestore.dart';

/// A chat message posted inside a Nus·Nus group.
class GroupMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  /// Firebase Storage path for new private group images.
  final String? imagePath;
  /// Legacy field retained for previously stored image messages.
  final String? imageUrl;
  final DateTime? createdAt;
  final bool isEdited;

  const GroupMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    this.imagePath,
    this.imageUrl,
    this.createdAt,
    this.isEdited = false,
  });

  factory GroupMessage.fromJson(String id, Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    }

    return GroupMessage(
      id: id,
      senderUid: json['senderUid'] as String? ?? '',
      senderName: json['senderName'] as String? ?? 'Member',
      text: json['text'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: createdAt,
      isEdited: json['isEdited'] as bool? ?? false,
    );
  }
}


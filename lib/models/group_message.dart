import 'package:cloud_firestore/cloud_firestore.dart';

/// A chat message posted inside a Nus·Nus group.
class GroupMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  const GroupMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    this.createdAt,
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
      createdAt: createdAt,
    );
  }
}

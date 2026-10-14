import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_message.dart';

/// Firestore persistence for group conversation messages.
///
/// Messages are separate from expenses: chat text never changes balances.
/// Group membership is enforced by Firestore Security Rules.
class GroupChatRepository {
  GroupChatRepository._();

  static final GroupChatRepository instance = GroupChatRepository._();

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('messages');

  /// Streams the latest 100 messages, newest first.
  Stream<List<GroupMessage>> watchMessages(String groupId) {
    return _messages(groupId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupMessage.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Sends a text message. Validation is repeated in Firestore Rules.
  Future<void> sendMessage({
    required String groupId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (groupId.trim().isEmpty) {
      throw ArgumentError('A group is required.');
    }
    if (senderUid.trim().isEmpty) {
      throw ArgumentError('You must be signed in to send a message.');
    }
    if (trimmed.isEmpty || trimmed.length > 1000) {
      throw ArgumentError('Messages must contain 1–1000 characters.');
    }

    await _messages(groupId).add({
      'senderUid': senderUid,
      'senderName': senderName.trim().isEmpty ? 'Member' : senderName.trim(),
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

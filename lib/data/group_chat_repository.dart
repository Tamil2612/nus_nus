import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/group_message.dart';

/// Firestore persistence for group conversation messages.
class GroupChatRepository {
  GroupChatRepository._();
  static final GroupChatRepository instance = GroupChatRepository._();

  static const int pageSize = 100;
  static const int maxMessageLength = 1000;
  static const int maxImageBytes = 5 * 1024 * 1024;

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      FirebaseFirestore.instance.collection('groups').doc(groupId).collection('messages');

  Stream<List<GroupMessage>> watchMessages(String groupId) =>
      _messages(groupId)
          .orderBy('createdAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(pageSize)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => GroupMessage.fromJson(doc.id, doc.data()))
              .toList());

  Future<List<GroupMessage>> fetchOlderMessages({
    required String groupId,
    required GroupMessage before,
  }) async {
    final createdAt = before.createdAt;
    if (createdAt == null) return const [];
    final snapshot = await _messages(groupId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .startAfter([Timestamp.fromDate(createdAt), before.id])
        .limit(pageSize)
        .get();
    return snapshot.docs
        .map((doc) => GroupMessage.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<String> uploadImage({
    required String groupId,
    required String senderUid,
    required Uint8List bytes,
  }) async {
    if (groupId.trim().isEmpty || senderUid.trim().isEmpty) {
      throw ArgumentError('A group and signed-in user are required.');
    }
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw ArgumentError('Images must be smaller than 5 MB.');
    }
    final path = 'groups/$groupId/chat/$senderUid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await FirebaseStorage.instance.ref(path).putData(
      bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }

  Future<void> sendImageMessage({
    required String groupId,
    required String senderUid,
    required String senderName,
    required Uint8List bytes,
  }) async {
    final imagePath = await uploadImage(groupId: groupId, senderUid: senderUid, bytes: bytes);
    try {
      await sendMessage(groupId: groupId, senderUid: senderUid,
        senderName: senderName, text: '', imagePath: imagePath);
    } catch (_) {
      try { await FirebaseStorage.instance.ref(imagePath).delete(); } catch (_) {}
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderUid,
    required String senderName,
    required String text,
    String? imagePath,
  }) async {
    final trimmed = text.trim();
    if (groupId.trim().isEmpty) throw ArgumentError('A group is required.');
    if (senderUid.trim().isEmpty) throw ArgumentError('You must be signed in to send a message.');
    if (trimmed.length > maxMessageLength) throw ArgumentError('Messages cannot exceed 1000 characters.');
    if (trimmed.isEmpty && (imagePath == null || imagePath.isEmpty)) {
      throw ArgumentError('Add a message or an image.');
    }
    if (imagePath != null && !imagePath.startsWith('groups/$groupId/chat/$senderUid/')) {
      throw ArgumentError('The image path is invalid for this sender and group.');
    }
    final data = <String, dynamic>{
      'senderUid': senderUid,
      'senderName': senderName.trim().isEmpty ? 'Member' : senderName.trim(),
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (imagePath != null && imagePath.isNotEmpty) data['imagePath'] = imagePath;
    await _messages(groupId).add(data);
  }

  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) {
      throw ArgumentError('Messages must contain 1–1000 characters.');
    }
    await _messages(groupId).doc(messageId).update({'text': trimmed, 'isEdited': true});
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    final ref = _messages(groupId).doc(messageId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final imagePath = data['imagePath'];
    if (imagePath is String && imagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(imagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    await ref.delete();
  }
}

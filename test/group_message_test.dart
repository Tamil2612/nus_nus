import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nus_nus/models/group_message.dart';

void main() {
  group('GroupMessage', () {
    test('parses a text message and edited flag', () {
      final createdAt = DateTime.utc(2026, 10, 16);
      final message = GroupMessage.fromJson('m1', {
        'senderUid': 'uid-1',
        'senderName': 'Tamil',
        'text': 'Hello',
        'createdAt': Timestamp.fromDate(createdAt),
        'isEdited': true,
      });
      expect(message.id, 'm1');
      expect(message.senderUid, 'uid-1');
      expect(message.senderName, 'Tamil');
      expect(message.text, 'Hello');
      expect(message.isEdited, isTrue);
      expect(message.imagePath, isNull);
      expect(message.createdAt, createdAt);
    });

    test('supports Storage paths and legacy image URLs', () {
      final createdAt = DateTime.utc(2026, 10, 16);
      final storageMessage = GroupMessage.fromJson('m2', {
        'senderUid': 'uid-2',
        'senderName': 'Member',
        'text': '',
        'imagePath': 'groups/g1/chat/uid-2/123.jpg',
        'createdAt': Timestamp.fromDate(createdAt),
      });
      final legacyMessage = GroupMessage.fromJson('m3', {
        'senderUid': 'uid-3',
        'senderName': 'Member',
        'text': '',
        'imageUrl': 'data:image/jpeg;base64,AA==',
        'createdAt': Timestamp.fromDate(createdAt),
      });
      expect(storageMessage.imagePath, 'groups/g1/chat/uid-2/123.jpg');
      expect(storageMessage.imageUrl, isNull);
      expect(legacyMessage.imageUrl, startsWith('data:image/jpeg'));
    });
  });
}

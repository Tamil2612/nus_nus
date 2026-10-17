import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in a group's settlement audit log (`groups/{id}/settlements`).
///
/// Written only by the trusted settlement callables. A settlement that is
/// later undone stays in the log with [reverted] set, so the history is never
/// silently rewritten.
class SettlementRecord {
  final String id;
  final String groupId;

  /// Person ids (within the group) of the debtor who paid and the creditor
  /// who received.
  final int fromId;
  final int toId;

  /// The net amount paid outside the app, in minor units (cents/fils).
  final int amountCents;

  /// Opposing debts cancelled against each other as part of this settlement.
  final int offsetCents;
  final String currency;
  final String recordedBy;
  final List<String> participantUids;
  final bool reverted;
  final DateTime? createdAt;
  final DateTime? revertedAt;

  const SettlementRecord({
    required this.id,
    required this.groupId,
    required this.fromId,
    required this.toId,
    required this.amountCents,
    required this.offsetCents,
    required this.currency,
    required this.recordedBy,
    required this.participantUids,
    required this.reverted,
    this.createdAt,
    this.revertedAt,
  });

  double get amount => amountCents / 100;
  double get offsetAmount => offsetCents / 100;

  /// Whether [uid] is one of the two people who may undo this settlement.
  bool canBeUndoneBy(String? uid) =>
      uid != null && !reverted && participantUids.contains(uid);

  factory SettlementRecord.fromDoc(
    String groupId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? const <String, dynamic>{};
    return SettlementRecord(
      id: doc.id,
      groupId: groupId,
      fromId: (json['fromId'] as num?)?.toInt() ?? 0,
      toId: (json['toId'] as num?)?.toInt() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      offsetCents: (json['offsetCents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? 'AED',
      recordedBy: (json['recordedBy'] as String?) ?? '',
      participantUids: ((json['participantUids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      reverted: json['status'] == 'reverted',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      revertedAt: (json['revertedAt'] as Timestamp?)?.toDate(),
    );
  }
}

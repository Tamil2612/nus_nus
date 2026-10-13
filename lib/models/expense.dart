import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  /// Firestore document id within the group's `expenses` subcollection.
  final String id;
  final String desc;
  final double amount;
  final int payerId;
  /// Maps Person ID to the amount they owe for this specific expense.
  final Map<int, double> splitMap;
  final bool isSettlement;
  /// Set of person IDs whose entire share has been marked paid (legacy-compatible).
  final Set<int> settledBy;
  /// Amount paid toward each person's share, in the group's currency.
  /// Keys are participant IDs; this supports partial pairwise settlements.
  final Map<int, double> settledAmounts;
  /// Uid of whoever logged this expense — any member of the group can add
  /// one, not just the creator, so this is what "Added by X" is built
  /// from. Null for expenses written before this field existed.
  final String? addedBy;
  final DateTime? createdAt;

  Expense({
    required this.id,
    required this.desc,
    required this.amount,
    required this.payerId,
    required this.splitMap,
    this.isSettlement = false,
    Set<int>? settledBy,
    Map<int, double>? settledAmounts,
    this.addedBy,
    this.createdAt,
  }) : settledBy = settledBy ?? {},
       settledAmounts = settledAmounts ?? const {};

  List<int> get splitWith => splitMap.keys.toList();

  // -- Per-expense settlement status ---------------------------------------
  //
  // One definition, used by the activity feed, the detail screen, the
  // provider and the balance calculator, so they can never disagree.

  /// Whether [personId]'s share of this expense counts as paid. The payer
  /// is always paid (they fronted the money), and legacy settlement records
  /// are paid by definition.
  bool isPersonPaid(int personId) {
    if (isSettlement || personId == payerId || settledBy.contains(personId)) {
      return true;
    }
    final share = splitMap[personId];
    if (share == null) return false;
    return (share - (settledAmounts[personId] ?? 0)).abs() <= 0.005;
  }

  /// Amount of [personId]'s share that remains outstanding.
  double remainingShare(int personId) {
    if (isSettlement || personId == payerId || settledBy.contains(personId)) {
      return 0;
    }
    final share = splitMap[personId] ?? 0;
    return (share - (settledAmounts[personId] ?? 0)).clamp(0.0, share).toDouble();
  }

  /// Whether some, but not all, of this person's share has been settled.
  bool isPersonPartiallyPaid(int personId) {
    if (isPersonPaid(personId)) return false;
    final paid = settledAmounts[personId] ?? 0;
    return paid > 0.005 && remainingShare(personId) > 0.005;
  }

  /// Number of split participants whose share is paid (payer included when
  /// they're part of the split).
  int get settledCount => splitMap.keys.where(isPersonPaid).length;

  /// Number of people the expense is split between.
  int get participantCount => splitMap.length;

  /// True once every participant's share is paid.
  bool get isFullySettled => splitMap.keys.every(isPersonPaid);

  /// True if anyone other than the payer has paid their share yet.
  bool get hasPaymentsFromOthers =>
      splitMap.keys.any((id) => id != payerId && isPersonPaid(id));

  Expense copyWith({
    String? desc,
    double? amount,
    int? payerId,
    Map<int, double>? splitMap,
    bool? isSettlement,
    Set<int>? settledBy,
    Map<int, double>? settledAmounts,
    String? addedBy,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id,
      desc: desc ?? this.desc,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      splitMap: splitMap ?? this.splitMap,
      isSettlement: isSettlement ?? this.isSettlement,
      settledBy: settledBy ?? this.settledBy,
      settledAmounts: settledAmounts ?? this.settledAmounts,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Firestore map keys must be strings, so splitMap's int keys are encoded
  // as strings on the way out and parsed back to int on the way in.
  Map<String, dynamic> toJson() => {
    'desc': desc,
    'amount': amount,
    'payerId': payerId,
    'splitMap': splitMap.map((k, v) => MapEntry(k.toString(), v)),
    'isSettlement': isSettlement,
    // Stored as a list of id strings (Firestore can't encode MapEntry).
    'settledBy': settledBy.map((e) => e.toString()).toList(),
    'settledAmounts': settledAmounts.map((k, v) => MapEntry(k.toString(), v)),
    'addedBy': addedBy,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };

  /// [id] is passed separately rather than read from [json] because it
  /// comes from the Firestore document id, not a field inside the
  /// document body.
  factory Expense.fromJson(String id, Map<String, dynamic> json) => Expense(
    id: id,
    desc: json['desc'] as String? ?? 'Untitled expense',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    payerId: json['payerId'] as int? ?? 0,
    splitMap: (json['splitMap'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
    ),
    isSettlement: json['isSettlement'] as bool? ?? false,
    settledBy: _parseSettledBy(json['settledBy']),
    settledAmounts: _parseSettledAmounts(json['settledAmounts']),
    addedBy: json['addedBy'] as String?,
    createdAt: json['createdAt'] != null ? (json['createdAt'] as Timestamp).toDate() : null,
  );

  static Map<int, double> _parseSettledAmounts(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(
        int.parse(key.toString()),
        (value as num).toDouble(),
      ));
    }
    return {};
  }

  static Set<int> _parseSettledBy(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => int.parse(e.toString())).toSet();
    }
    if (raw is Map) {
      // Tolerate a {"id": true} map shape.
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => int.parse(e.key.toString()))
          .toSet();
    }
    return {};
  }
}
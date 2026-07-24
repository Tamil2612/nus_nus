class Expense {
  /// Firestore document id within the group's `expenses` subcollection.
  final String id;
  final String desc;
  final double amount;
  final int payerId;
  /// Maps Person ID to the amount they owe for this specific expense.
  final Map<int, double> splitMap;
  final bool isSettlement;
  /// Uid of whoever logged this expense — any member of the group can add
  /// one, not just the creator, so this is what "Added by X" is built
  /// from. Null for expenses written before this field existed.
  final String? addedBy;

  Expense({
    required this.id,
    required this.desc,
    required this.amount,
    required this.payerId,
    required this.splitMap,
    this.isSettlement = false,
    this.addedBy,
  });

  List<int> get splitWith => splitMap.keys.toList();

  Expense copyWith({
    String? desc,
    double? amount,
    int? payerId,
    Map<int, double>? splitMap,
    bool? isSettlement,
  }) {
    return Expense(
      id: id,
      desc: desc ?? this.desc,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      splitMap: splitMap ?? this.splitMap,
      isSettlement: isSettlement ?? this.isSettlement,
      addedBy: addedBy,
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
        'addedBy': addedBy,
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
        addedBy: json['addedBy'] as String?,
      );
}

class Expense {
  final int id;
  final String desc;
  final double amount;
  final int payerId;
  /// Maps Person ID to the amount they owe for this specific expense.
  final Map<int, double> splitMap;
  final bool isSettlement;

  Expense({
    required this.id,
    required this.desc,
    required this.amount,
    required this.payerId,
    required this.splitMap,
    this.isSettlement = false,
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
    );
  }

  // Firestore map keys must be strings, so splitMap's int keys are encoded
  // as strings on the way out and parsed back to int on the way in.
  Map<String, dynamic> toJson() => {
        'id': id,
        'desc': desc,
        'amount': amount,
        'payerId': payerId,
        'splitMap': splitMap.map((k, v) => MapEntry(k.toString(), v)),
        'isSettlement': isSettlement,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as int,
        desc: json['desc'] as String,
        amount: (json['amount'] as num).toDouble(),
        payerId: json['payerId'] as int,
        splitMap: (json['splitMap'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
        ),
        isSettlement: json['isSettlement'] as bool? ?? false,
      );
}

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
}

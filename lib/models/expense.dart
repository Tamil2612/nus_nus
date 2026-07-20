class Expense {
  final int id;
  final String desc;
  final double amount;
  final int payerId;
  final List<int> splitWith;

  Expense({
    required this.id,
    required this.desc,
    required this.amount,
    required this.payerId,
    required this.splitWith,
  });

  double get shareEach => splitWith.isEmpty ? 0 : amount / splitWith.length;
}

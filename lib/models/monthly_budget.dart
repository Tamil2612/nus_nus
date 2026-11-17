import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyBudget {
  final String monthId;
  final double amount;
  final String currency;
  final Map<String, double> categoryBudgets;
  final DateTime? updatedAt;

  const MonthlyBudget({
    required this.monthId,
    required this.amount,
    required this.currency,
    this.categoryBudgets = const {},
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'categoryBudgets': categoryBudgets,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory MonthlyBudget.fromJson(String monthId, Map<String, dynamic> json) =>
      MonthlyBudget(
        monthId: monthId,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: (json['currency'] as String? ?? 'AED').toUpperCase(),
        categoryBudgets: (json['categoryBudgets'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );

  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

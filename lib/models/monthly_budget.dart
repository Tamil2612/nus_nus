import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyBudget {
  final String monthId;
  final double amount;
  final String currency;
  final DateTime? updatedAt;

  const MonthlyBudget({
    required this.monthId,
    required this.amount,
    required this.currency,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory MonthlyBudget.fromJson(String monthId, Map<String, dynamic> json) =>
      MonthlyBudget(
        monthId: monthId,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: (json['currency'] as String? ?? 'AED').toUpperCase(),
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );

  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

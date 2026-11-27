import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  const ExpenseCategory(this.id, this.label, this.icon);

  static const all = <ExpenseCategory>[
    ExpenseCategory('food', 'Food', Icons.restaurant_rounded),
    ExpenseCategory('transport', 'Transport', Icons.directions_car_rounded),
    ExpenseCategory('shopping', 'Shopping', Icons.shopping_bag_rounded),
    ExpenseCategory('rent', 'Rent', Icons.home_rounded),
    ExpenseCategory('bills', 'Bills', Icons.receipt_long_rounded),
    ExpenseCategory('entertainment', 'Entertainment', Icons.movie_rounded),
    ExpenseCategory('health', 'Health', Icons.health_and_safety_rounded),
    ExpenseCategory('education', 'Education', Icons.school_rounded),
    ExpenseCategory('other', 'Other', Icons.category_rounded),
  ];

  static ExpenseCategory? byId(String? id) {
    if (id == null) return null;
    for (final category in all) {
      if (category.id == id) return category;
    }
    return null;
  }

  static bool isValid(String? id) =>
      id == null || all.any((category) => category.id == id);
}

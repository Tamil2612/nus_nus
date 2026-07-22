import 'person.dart';
import 'expense.dart';

class Group {
  final int id;
  final String name;
  final List<Person> members;
  final List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    this.members = const [],
    this.expenses = const [],
  });

  Group copyWith({
    String? name,
    List<Person>? members,
    List<Expense>? expenses,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      members: members ?? this.members,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((p) => p.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as int,
        name: json['name'] as String,
        members: (json['members'] as List? ?? [])
            .map((m) => Person.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        expenses: (json['expenses'] as List? ?? [])
            .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

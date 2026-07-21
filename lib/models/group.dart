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
}

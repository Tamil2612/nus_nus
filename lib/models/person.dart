import 'package:flutter/material.dart';

class Person {
  final int id;
  final String name;
  final Color color;
  /// True once the person has been "removed" from an active group but still
  /// has expense history — we keep them around so names/colors/balances in
  /// past expenses stay correct, we just hide them from pickers.
  final bool archived;

  Person({
    required this.id,
    required this.name,
    required this.color,
    this.archived = false,
  });

  Person copyWith({bool? archived}) {
    return Person(
      id: id,
      name: name,
      color: color,
      archived: archived ?? this.archived,
    );
  }
}

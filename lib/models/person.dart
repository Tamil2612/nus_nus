import 'package:flutter/material.dart';

class Person {
  final int id;
  final String name;
  final Color color;
  /// True once the person has been "removed" from an active group but still
  /// has expense history — we keep them around so names/colors/balances in
  /// past expenses stay correct, we just hide them from pickers.
  final bool archived;
  /// Firebase uid of the registered account this member was added from, if
  /// any. Null for people added by typing a name manually — those are just
  /// local labels with no login of their own.
  final String? linkedUserId;

  Person({
    required this.id,
    required this.name,
    required this.color,
    this.archived = false,
    this.linkedUserId,
  });

  Person copyWith({bool? archived, String? linkedUserId}) {
    return Person(
      id: id,
      name: name,
      color: color,
      archived: archived ?? this.archived,
      linkedUserId: linkedUserId ?? this.linkedUserId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'archived': archived,
        'linkedUserId': linkedUserId,
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as int,
        name: json['name'] as String,
        color: Color(json['color'] as int),
        archived: json['archived'] as bool? ?? false,
        linkedUserId: json['linkedUserId'] as String?,
      );
}

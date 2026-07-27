import 'person.dart';
import 'expense.dart';

class Group {
  /// Firestore document id. Empty string for a group that hasn't been
  /// written yet (never observed by the UI — [SplitProvider] always
  /// assigns a real id before the group is shown).
  final String id;
  final String name;
  final String currency;

  /// Uid of the account that created this group. The creator is the only
  /// one who can rename/delete the group, manage its member list, edit or
  /// delete an expense, or settle a balance up. Every other member linked
  /// in (via a [Person.linkedUserId]) can see everything and can log new
  /// expenses, but can't touch anyone else's — enforced both client-side
  /// (UI hides the controls) and server-side (see the Firestore rules in
  /// the repo).
  final String ownerId;

  /// Display name of the owner, captured at creation time so every linked
  /// member can show "shared by X" without an extra lookup. Best-effort —
  /// always prefer a live lookup (member directory) if one is available,
  /// since a person can rename themselves after a group was created.
  final String ownerName;

  final List<Person> members;

  /// In-memory only — expenses live in the group's `expenses`
  /// subcollection (so any member can add one without needing write
  /// access to the rest of the document), not embedded on this document.
  /// [SplitProvider] merges the subcollection's live data in here; it's
  /// never read from or written to the group document itself.
  final List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    this.currency = 'AED',
    this.ownerName = '',
    this.members = const [],
    this.expenses = const [],
  });

  bool isOwnedBy(String? uid) => uid != null && uid == ownerId;

  /// Every account uid that should be able to read this group: the owner,
  /// plus every registered member linked into it. Firestore has no way to
  /// query "am I the owner OR in this array" in one clause, so the owner
  /// is folded into the same array and the security rules simply check
  /// `request.auth.uid in resource.data.memberUids`.
  List<String> get memberUids {
    final ids = <String>{ownerId};
    for (final p in members) {
      if (p.linkedUserId != null) ids.add(p.linkedUserId!);
    }
    return ids.toList();
  }

  Group copyWith({
    String? name,
    String? currency,
    List<Person>? members,
    List<Expense>? expenses,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      ownerId: ownerId,
      ownerName: ownerName,
      members: members ?? this.members,
      expenses: expenses ?? this.expenses,
    );
  }

  /// Metadata only — deliberately excludes [expenses], which live in the
  /// subcollection and are written there directly instead.
  Map<String, dynamic> toJson() => {
        'name': name,
        'currency': currency,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'memberUids': memberUids,
        'members': members.map((p) => p.toJson()).toList(),
      };

  /// [id] is passed separately rather than read from [json] because it
  /// comes from the Firestore document id, not a field inside the
  /// document body. [expenses] always starts empty here — [SplitProvider]
  /// fills it in from the live subcollection stream.
  factory Group.fromJson(String id, Map<String, dynamic> json) => Group(
        id: id,
        name: json['name'] as String? ?? 'Untitled group',
        currency: json['currency'] as String? ?? 'AED',
        ownerId: json['ownerId'] as String? ?? '',
        ownerName: json['ownerName'] as String? ?? '',
        members: (json['members'] as List? ?? [])
            .map((m) => Person.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

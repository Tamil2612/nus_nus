/// A registered account's public profile — what shows up in the "add from
/// registered members" picker. Deliberately doesn't carry any private
/// app data (groups/expenses); that lives separately per-user so that
/// listing the directory never exposes anyone's private balances.
class AppUser {
  final String uid;
  final String name;
  final String email;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class KintoneUser {
  final String code;
  final String name;
  final String email;

  KintoneUser({required this.code, required this.name, required this.email});

  factory KintoneUser.fromJson(Map<String, dynamic> json) {
    return KintoneUser(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }

  // 検索用：名前またはコードに検索文字列が含まれるか
  bool matches(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowerQuery) ||
        code.toLowerCase().contains(lowerQuery);
  }
}

class Mention {
  final KintoneUser user;

  Mention({required this.user});

  Map<String, dynamic> toJson() {
    return {'code': user.code, 'type': 'USER'};
  }
}

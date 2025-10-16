class Comment {
  final String id;
  final String text;
  final String createdAt;
  final CommentCreator creator;

  Comment({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.creator,
  });

  factory Comment.fromKintoneJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      text: json['text'] ?? '',
      createdAt: json['createdAt'] ?? '',
      creator: CommentCreator.fromKintoneJson(json['creator'] ?? {}),
    );
  }

  // 日時を読みやすい形式に変換
  String get formattedDate {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'たった今';
          }
          return '${difference.inMinutes}分前';
        }
        return '${difference.inHours}時間前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}日前';
      } else {
        return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
      }
    } catch (e) {
      return createdAt;
    }
  }
}

class CommentCreator {
  final String code;
  final String name;

  CommentCreator({required this.code, required this.name});

  factory CommentCreator.fromKintoneJson(Map<String, dynamic> json) {
    return CommentCreator(code: json['code'] ?? '', name: json['name'] ?? '不明');
  }
}

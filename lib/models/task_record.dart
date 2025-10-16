class TaskRecord {
  final String taskName;
  final String taskStatus;
  final String taskDetail;
  final String workHours;
  final String dueDate;
  final String assignee;
  final String reviewer;
  final String projectName;
  final String clientName;
  final List<AttachmentFile> attachments;

  TaskRecord({
    required this.taskName,
    required this.taskStatus,
    required this.taskDetail,
    required this.workHours,
    required this.dueDate,
    required this.assignee,
    required this.reviewer,
    required this.projectName,
    required this.clientName,
    required this.attachments,
  });

  factory TaskRecord.fromKintoneJson(Map<String, dynamic> json) {
    String getValue(String key) {
      return json[key]?['value']?.toString() ?? '';
    }

    // ユーザー選択フィールドから名前を取得
    String getUserName(String key) {
      final userData = json[key]?['value'];
      if (userData == null) return '';

      if (userData is List && userData.isNotEmpty) {
        return userData[0]['name'] ?? '';
      }
      return '';
    }

    // リッチテキストからHTMLタグを除去
    String getPlainText(String key) {
      String text = getValue(key);
      // HTMLタグを除去
      text = text.replaceAll(RegExp(r'<[^>]*>'), '');
      // HTMLエンティティをデコード
      text = text
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");
      return text.trim();
    }

    List<AttachmentFile> getAttachments() {
      final attachmentsData = json['添付ファイル']?['value'] as List<dynamic>?;
      if (attachmentsData == null) return [];

      return attachmentsData.map((file) {
        return AttachmentFile(
          name: file['name'] ?? '',
          contentType: file['contentType'] ?? '',
          size: file['size']?.toString() ?? '0',
          fileKey: file['fileKey'] ?? '',
        );
      }).toList();
    }

    return TaskRecord(
      taskName: getValue('タスク名'),
      taskStatus: getValue('タスクステータス'),
      taskDetail: getPlainText('タスク詳細'),
      workHours: getValue('工数'),
      dueDate: getValue('対応期限'),
      assignee: getUserName('対応者'),
      reviewer: getUserName('レビュー者'),
      projectName: getValue('案件名'),
      clientName: getValue('取引先名'),
      attachments: getAttachments(),
    );
  }
}

class AttachmentFile {
  final String name;
  final String contentType;
  final String size;
  final String fileKey;

  AttachmentFile({
    required this.name,
    required this.contentType,
    required this.size,
    required this.fileKey,
  });
}

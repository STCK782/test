import 'package:flutter/material.dart';
import 'task_detail_screen.dart';
import '../services/auth_manager.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final TextEditingController _recordIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _basicAuthController = TextEditingController();

  bool _useBasicAuth = false;
  final AuthManager _authManager = AuthManager();

  @override
  void dispose() {
    _recordIdController.dispose();
    _usernameController.dispose();
    _basicAuthController.dispose();
    super.dispose();
  }

  void _navigateToTaskDetail() {
    final recordId = _recordIdController.text.trim();
    if (recordId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('レコード番号を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 認証情報を設定
    if (_useBasicAuth) {
      final username = _usernameController.text.trim();
      final basicAuth = _basicAuthController.text.trim();

      if (username.isEmpty || basicAuth.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ユーザーネームとBasic認証トークンを入力してください'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _authManager.setCredentials(username, basicAuth);
    } else {
      _authManager.useApiToken();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(recordId: recordId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF5),
      appBar: AppBar(
        title: const Text('タスク管理アプリ - デモ環境'),
        backgroundColor: const Color(0xFF3B4A6B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.task_alt,
                      size: 64,
                      color: Color(0xFF3B4A6B),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'タスク詳細を表示',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // レコード番号入力
                    TextField(
                      controller: _recordIdController,
                      decoration: const InputDecoration(
                        labelText: 'レコード番号',
                        hintText: '例: 1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _navigateToTaskDetail(),
                    ),
                    const SizedBox(height: 24),

                    // 認証方式切り替え
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bug_report,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'デバッグ用認証設定',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _useBasicAuth,
                                onChanged: (value) {
                                  setState(() {
                                    _useBasicAuth = value ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'Basic認証を使用する（コメント投稿者名表示テスト用）',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (_useBasicAuth) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'ユーザーネーム',
                                hintText: 'Kintoneのログインユーザー名',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _basicAuthController,
                              decoration: const InputDecoration(
                                labelText: 'Basic認証トークン (Base64)',
                                hintText:
                                    'username:password を Base64 エンコードしたもの',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.key),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '※ username:password を Base64 エンコードした文字列を入力',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _navigateToTaskDetail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B4A6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'タスク詳細を表示',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '使い方',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Kintoneに登録されているレコード番号を入力してください',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '2. コメント投稿者名をテストする場合は「Basic認証を使用する」をチェック',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '3. 「タスク詳細を表示」ボタンをクリックします',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '※ 通常モード: .envファイルのAPIトークンを使用',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            '※ Basic認証モード: 入力した認証情報でコメント投稿',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

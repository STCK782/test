import 'package:flutter/material.dart';
import 'task_detail_screen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final TextEditingController _recordIdController = TextEditingController();

  @override
  void dispose() {
    _recordIdController.dispose();
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
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
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
                          '2. 「タスク詳細を表示」ボタンをクリックします',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '3. タスクの詳細情報が表示されます',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '※ .envファイルに正しいAPI設定が必要です',
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
    );
  }
}

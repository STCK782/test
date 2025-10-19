import 'package:flutter/material.dart';
import 'dart:io';
import '../models/task_record.dart';
import '../services/kintone_service.dart';
import '../widgets/comment_section.dart';

class TaskDetailScreen extends StatefulWidget {
  final String recordId;

  const TaskDetailScreen({super.key, required this.recordId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final KintoneService _kintoneService = KintoneService();
  TaskRecord? _taskRecord;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTaskRecord();
  }

  Future<void> _loadTaskRecord() async {
    try {
      final record = await _kintoneService.getRecord(widget.recordId);
      setState(() {
        _taskRecord = record;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(AttachmentFile file) async {
    // ダウンロード中のダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('ダウンロード中...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final filePath = await _kintoneService.downloadFile(
        file.fileKey,
        file.name,
      );

      if (!mounted) return;

      // ダイアログを閉じる
      Navigator.of(context).pop();

      // 成功メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ファイルを保存しました\n$filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'フォルダを開く',
            textColor: Colors.white,
            onPressed: () async {
              try {
                final directory = Directory(filePath).parent.path;
                // Windowsのエクスプローラーでフォルダを開く
                await Process.run('explorer', [directory]);
              } catch (e) {
                // エラーは無視
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // ダイアログを閉じる
      Navigator.of(context).pop();

      // エラーメッセージを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('ダウンロードエラー'),
              ],
            ),
            content: Text('ファイルのダウンロードに失敗しました。\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _deleteRecord() async {
    // 削除確認ダイアログを表示
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('削除確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('このタスクを削除してもよろしいですか?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'タスク名: ${_taskRecord?.taskName ?? ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('対応者: ${_taskRecord?.assignee ?? "未設定"}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '※この操作は取り消せません',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // ローディング表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('削除中...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      await _kintoneService.deleteRecord(widget.recordId);

      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // 成功メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('タスクを削除しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // 前の画面に戻る
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // エラーメッセージを表示
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('削除エラー'),
              ],
            ),
            content: Text('削除に失敗しました。\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(32),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'エラーが発生しました',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B4A6B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '戻る',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _loadTaskRecord();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B4A6B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Color(0xFF3B4A6B)),
                            ),
                            child: const Text(
                              '再試行',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_taskRecord == null) {
      return const Center(child: Text('データが取得できませんでした'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildMainContent(availableHeight)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: availableHeight - 40,
                    child: CommentSection(recordId: widget.recordId),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(double availableHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: availableHeight - 40, // パディング分を引く
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskHeader(),
              const SizedBox(height: 20),
              _buildTaskDetails(),
              const SizedBox(height: 20),
              _buildAssignmentInfo(),
              const SizedBox(height: 20),
              _buildAttachments(),
              const SizedBox(height: 20),
              _buildProjectInfo(),
              const SizedBox(height: 20),
            ],
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  'タスク',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                flex: 1,
                child: Text(
                  'ステータス',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  _taskRecord!.taskName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _taskRecord!.taskStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2196F3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'タスク詳細',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            _taskRecord!.taskDetail.isEmpty
                ? '詳細情報なし'
                : _taskRecord!.taskDetail,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '工数',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _taskRecord!.workHours.isEmpty
                        ? '未設定'
                        : '${_taskRecord!.workHours}時間',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '対応期限',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _taskRecord!.dueDate.isEmpty ? '未設定' : _taskRecord!.dueDate,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '対応者',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _taskRecord!.assignee.isEmpty
                        ? '未設定'
                        : _taskRecord!.assignee,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'レビュー者',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _taskRecord!.reviewer.isEmpty
                        ? '未設定'
                        : _taskRecord!.reviewer,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '添付ファイル',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_taskRecord!.attachments.isEmpty)
            const Text(
              '添付ファイルなし',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _taskRecord!.attachments.map((file) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => _downloadFile(file),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 18,
                          color: Color(0xFF3B4A6B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.name,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2196F3),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.download,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '案件名',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _taskRecord!.projectName.isEmpty
                            ? '未設定'
                            : _taskRecord!.projectName,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '取引先名',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _taskRecord!.clientName.isEmpty
                            ? '未設定'
                            : _taskRecord!.clientName,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 45,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B4A6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('< 戻る', style: TextStyle(fontSize: 16)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 140,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                // 編集機能は今回は実装しない
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B4A6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('編集ボタン', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            height: 45,
            child: ElevatedButton(
              onPressed: _deleteRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('削除ボタン', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

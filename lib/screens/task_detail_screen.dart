import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/task_record.dart';
import '../models/user.dart';
import '../services/kintone_service.dart';
import '../services/auth_manager.dart';
import '../widgets/comment_section.dart';

class TaskDetailScreen extends StatefulWidget {
  final String recordId;

  const TaskDetailScreen({super.key, required this.recordId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final KintoneService _kintoneService = KintoneService();
  final AuthManager _authManager = AuthManager();

  TaskRecord? _taskRecord;
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  String? _errorMessage;

  // 編集用コントローラー
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskDetailController = TextEditingController();
  final TextEditingController _workHoursController = TextEditingController();
  final TextEditingController _projectNoController = TextEditingController();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _assigneeSearchController =
      TextEditingController();
  final TextEditingController _reviewerSearchController =
      TextEditingController();

  // 編集用の状態
  String? _selectedStatus;
  KintoneUser? _selectedAssignee;
  KintoneUser? _selectedReviewer;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<AttachmentFile> _editingAttachments = [];
  List<String> _newFileKeys = [];

  @override
  void initState() {
    super.initState();
    _loadTaskRecord();
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _taskDetailController.dispose();
    _workHoursController.dispose();
    _projectNoController.dispose();
    _projectNameController.dispose();
    _clientIdController.dispose();
    _clientNameController.dispose();
    _assigneeSearchController.dispose();
    _reviewerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskRecord() async {
    try {
      final record = await _kintoneService.getRecord(widget.recordId);
      setState(() {
        _taskRecord = record;
        _isLoading = false;
        _initializeEditFields();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initializeEditFields() {
    if (_taskRecord == null) return;

    _taskNameController.text = _taskRecord!.taskName;
    _taskDetailController.text = _taskRecord!.taskDetail;
    _workHoursController.text = _taskRecord!.workHours;
    _projectNameController.text = _taskRecord!.projectName;
    _clientNameController.text = _taskRecord!.clientName;

    // 案件No・取引先IDをTaskRecordから取得
    _projectNoController.text = _taskRecord!.projectNo;
    _clientIdController.text = _taskRecord!.clientId;

    // 添付ファイルのコピー
    _editingAttachments = List.from(_taskRecord!.attachments);
    _newFileKeys.clear();

    // ステータスの初期化
    final statusList = [
      'Open',
      'Waiting',
      'InProgress',
      'InReview',
      'Completed',
      'Rejected',
    ];
    if (_taskRecord!.taskStatus.isNotEmpty &&
        statusList.contains(_taskRecord!.taskStatus)) {
      _selectedStatus = _taskRecord!.taskStatus;
    } else {
      _selectedStatus = null;
    }

    // 対応者の初期化（名前からユーザーオブジェクトを作成）
    if (_taskRecord!.assignee.isNotEmpty) {
      _selectedAssignee = KintoneUser(
        code: '', // コードは不明だが表示には名前を使用
        name: _taskRecord!.assignee,
        email: '',
      );
    } else {
      _selectedAssignee = null;
    }

    // レビュー者の初期化（名前からユーザーオブジェクトを作成）
    if (_taskRecord!.reviewer.isNotEmpty) {
      _selectedReviewer = KintoneUser(
        code: '', // コードは不明だが表示には名前を使用
        name: _taskRecord!.reviewer,
        email: '',
      );
    } else {
      _selectedReviewer = null;
    }

    // 対応期限をパース
    _selectedDate = null;
    _selectedTime = null;
    if (_taskRecord!.dueDate.isNotEmpty) {
      try {
        // "2025/10/17  5:49" のような形式をパース（スペースが複数ある場合も対応）
        final parts = _taskRecord!.dueDate.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          // 日付部分
          final dateParts = parts[0].split('/');
          if (dateParts.length == 3) {
            _selectedDate = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
            );
          }

          // 時刻部分
          if (parts.length >= 2) {
            final timeParts = parts[1].split(':');
            if (timeParts.length >= 2) {
              _selectedTime = TimeOfDay(
                hour: int.parse(timeParts[0]),
                minute: int.parse(timeParts[1]),
              );
            }
          }
        }
      } catch (e) {
        // パースエラーは無視
        debugPrint('日付パースエラー: $e, 対象: ${_taskRecord!.dueDate}');
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _initializeEditFields();
      }
    });
  }

  Future<void> _saveRecord() async {
    if (_taskNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('タスク名を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String dueDate = '';
      if (_selectedDate != null && _selectedTime != null) {
        // 日時を結合（UTC時間に変換）
        final combinedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        // Kintone形式: 2014-01-11T12:00Z (秒なし、UTC)
        final utcDateTime = combinedDateTime.toUtc();
        dueDate =
            '${utcDateTime.year.toString().padLeft(4, '0')}-${utcDateTime.month.toString().padLeft(2, '0')}-${utcDateTime.day.toString().padLeft(2, '0')}T${utcDateTime.hour.toString().padLeft(2, '0')}:${utcDateTime.minute.toString().padLeft(2, '0')}Z';
      }

      final attachmentsList = _editingAttachments.map((file) {
        return {'fileKey': file.fileKey};
      }).toList();

      final updateData = <String, dynamic>{
        'タスク名': {'value': _taskNameController.text},
        'タスク詳細': {'value': _taskDetailController.text},
        '工数': {
          'value': _workHoursController.text.trim().isEmpty
              ? ''
              : _workHoursController.text,
        },
        '添付ファイル': {'value': attachmentsList},
      };

      // 対応期限は値がある場合のみ送信
      if (dueDate.isNotEmpty) {
        updateData['対応期限'] = {'value': dueDate};
      }

      // タスクステータスは値がある場合のみ送信
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        updateData['タスクステータス'] = {'value': _selectedStatus};
      }

      // 対応者は値がある場合のみ送信
      if (_selectedAssignee != null) {
        if (_selectedAssignee!.code.isNotEmpty) {
          updateData['対応者'] = {
            'value': [
              {'code': _selectedAssignee!.code},
            ],
          };
        } else {
          // codeが空の場合は送信しない（既存値を維持）
        }
      }

      // レビュー者は値がある場合のみ送信
      if (_selectedReviewer != null) {
        if (_selectedReviewer!.code.isNotEmpty) {
          updateData['レビュー者'] = {
            'value': [
              {'code': _selectedReviewer!.code},
            ],
          };
        } else {
          // codeが空の場合は送信しない（既存値を維持）
        }
      }

      // 案件名・取引先名は常に送信
      updateData['案件名'] = {'value': _projectNameController.text};
      updateData['取引先名'] = {'value': _clientNameController.text};

      await _kintoneService.updateRecord(widget.recordId, updateData);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('レコードを更新しました'),
          backgroundColor: Colors.green,
        ),
      );

      _loadTaskRecord();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('更新エラー'),
            ],
          ),
          content: Text('レコードの更新に失敗しました。\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _selectUser(bool isAssignee) async {
    final searchQuery = isAssignee
        ? _assigneeSearchController.text.trim()
        : _reviewerSearchController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('ユーザーを検索中...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final users = await _kintoneService.getUsers();

      final filteredUsers = searchQuery.isEmpty
          ? users
          : users.where((user) {
              final query = searchQuery.toLowerCase();
              return user.name.toLowerCase().contains(query) ||
                  user.code.toLowerCase().contains(query);
            }).toList();

      if (!mounted) return;
      Navigator.of(context).pop();

      if (filteredUsers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('該当するユーザーが見つかりませんでした'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final selected = await showDialog<KintoneUser>(
        context: context,
        builder: (context) => _UserSelectionDialog(
          users: filteredUsers,
          searchQuery: searchQuery,
        ),
      );

      if (selected != null) {
        setState(() {
          if (isAssignee) {
            _selectedAssignee = selected;
          } else {
            _selectedReviewer = selected;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ユーザーの取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      // PowerShellを使ってWindowsのファイル選択ダイアログを表示
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '''
          Add-Type -AssemblyName System.Windows.Forms
          \$dialog = New-Object System.Windows.Forms.OpenFileDialog
          \$dialog.Multiselect = \$true
          \$dialog.Title = "ファイルを選択"
          \$dialog.Filter = "すべてのファイル (*.*)|*.*"
          if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
              \$dialog.FileNames -join "|"
          }
          ''',
      ]);

      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        return; // キャンセルまたはエラー
      }

      final filePaths = result.stdout.toString().trim().split('|');

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('ファイルをアップロード中...'),
                ],
              ),
            ),
          ),
        ),
      );

      for (final filePath in filePaths) {
        if (filePath.isEmpty) continue;

        try {
          final file = File(filePath);
          if (!file.existsSync()) continue;

          final fileName = filePath.split('\\').last;
          final fileKey = await _kintoneService.uploadFile(filePath);

          setState(() {
            _editingAttachments.add(
              AttachmentFile(
                name: fileName,
                contentType: fileName.contains('.')
                    ? fileName.split('.').last
                    : '',
                size: file.lengthSync().toString(),
                fileKey: fileKey,
              ),
            );
          });
        } catch (e) {
          if (!mounted) return;
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${filePath.split('\\').last}のアップロードに失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${filePaths.length}個のファイルをアップロードしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ファイル選択エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _editingAttachments.removeAt(index);
    });
  }

  void _clearProjectInfo() {
    setState(() {
      _projectNoController.clear();
      _projectNameController.clear();
      _clientIdController.clear();
      _clientNameController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('案件情報をクリアしました'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _searchProjects() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final results = await _kintoneService.searchProjects(
        projectNo: _projectNoController.text.trim().isEmpty
            ? null
            : _projectNoController.text.trim(),
        projectName: _projectNameController.text.trim().isEmpty
            ? null
            : _projectNameController.text.trim(),
        clientId: _clientIdController.text.trim().isEmpty
            ? null
            : _clientIdController.text.trim(),
        clientName: _clientNameController.text.trim().isEmpty
            ? null
            : _clientNameController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('該当する案件が見つかりませんでした'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _ProjectSelectionDialog(projects: results),
      );

      if (selected != null) {
        setState(() {
          _projectNoController.text =
              selected['案件No']?['value']?.toString() ?? '';
          _projectNameController.text =
              selected['案件名']?['value']?.toString() ?? '';
          _clientIdController.text =
              selected['取引先ID']?['value']?.toString() ?? '';
          _clientNameController.text =
              selected['取引先名']?['value']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('検索エラー'),
          content: Text('案件の検索に失敗しました。\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadFile(AttachmentFile file) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
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
      ),
    );

    try {
      final filePath = await _kintoneService.downloadFile(
        file.fileKey,
        file.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop();

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
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
        ),
      );
    }
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('このタスクを削除してもよろしいですか？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
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
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
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
      ),
    );

    try {
      await _kintoneService.deleteRecord(widget.recordId);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('タスクを削除しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
        ),
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
          ? _buildErrorView()
          : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'エラーが発生しました',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    ),
                    child: const Text('戻る', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_taskRecord == null) {
      return const Center(child: Text('データが取得できませんでした'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側: メインコンテンツ（スクロール可能）
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    // スクロール可能なコンテンツ
                    Positioned.fill(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: 100,
                          ), // ボタン分の余白
                          child: Column(
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
                        ),
                      ),
                    ),
                    // 浮かせたボタン（下部固定）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 85,
                      child: Container(
                        padding: const EdgeInsets.only(top: 30, bottom: 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFE8EEF5).withOpacity(0.0),
                              const Color(0xFFE8EEF5).withOpacity(0.95),
                              const Color(0xFFE8EEF5),
                            ],
                            stops: const [0.0, 0.3, 1.0],
                          ),
                        ),
                        child: _buildActionButtons(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // 右側: コメントセクション（固定）
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: availableHeight - 40,
                  child: CommentSection(recordId: widget.recordId),
                ),
              ),
            ],
          ),
        );
      },
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
            children: [
              Expanded(
                flex: 3,
                child: _isEditMode
                    ? TextField(
                        controller: _taskNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      )
                    : Text(
                        _taskRecord!.taskName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: _isEditMode
                    ? DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        hint: const Text('ステータスを選択'),
                        items: [
                          const DropdownMenuItem(
                            value: 'Open',
                            child: Text('Open'),
                          ),
                          const DropdownMenuItem(
                            value: 'Waiting',
                            child: Text('Waiting'),
                          ),
                          const DropdownMenuItem(
                            value: 'InProgress',
                            child: Text('InProgress'),
                          ),
                          const DropdownMenuItem(
                            value: 'InReview',
                            child: Text('InReview'),
                          ),
                          const DropdownMenuItem(
                            value: 'Completed',
                            child: Text('Completed'),
                          ),
                          const DropdownMenuItem(
                            value: 'Rejected',
                            child: Text('Rejected'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4FD),
                          borderRadius: BorderRadius.circular(8),
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
          _isEditMode
              ? TextField(
                  controller: _taskDetailController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                )
              : Text(
                  _taskRecord!.taskDetail.isEmpty
                      ? '詳細情報なし'
                      : _taskRecord!.taskDetail,
                  style: const TextStyle(fontSize: 16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工数
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '工数',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _isEditMode
                    ? SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _workHoursController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            suffixText: '時間',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      )
                    : Text(
                        _taskRecord!.workHours.isEmpty
                            ? '未設定'
                            : '${_taskRecord!.workHours}時間',
                        style: const TextStyle(fontSize: 16),
                      ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 対応期限
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '対応期限',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _isEditMode
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: InkWell(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedDate != null
                                              ? DateFormat(
                                                  'yyyy/M/d',
                                                ).format(_selectedDate!)
                                              : '日付',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: InkWell(
                                onTap: _selectTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedTime != null
                                              ? '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                              : '時間',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _taskRecord!.dueDate.isEmpty
                            ? '未設定'
                            : _taskRecord!.dueDate,
                        style: const TextStyle(fontSize: 16),
                      ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 対応者
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '対応者',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _isEditMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _assigneeSearchController,
                                    decoration: const InputDecoration(
                                      hintText: '検索...',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    onSubmitted: (_) => _selectUser(true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    onPressed: () => _selectUser(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B4A6B),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      '検索',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedAssignee != null) ...[
                            const SizedBox(height: 8),
                            Chip(
                              avatar: CircleAvatar(
                                backgroundColor: Colors.blue.shade700,
                                radius: 12,
                                child: Text(
                                  _selectedAssignee!.name[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              label: Text(
                                _selectedAssignee!.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedAssignee = null;
                                });
                              },
                              backgroundColor: Colors.blue.shade50,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.blue.shade200),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        _taskRecord!.assignee.isEmpty
                            ? '未設定'
                            : _taskRecord!.assignee,
                        style: const TextStyle(fontSize: 16),
                      ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // レビュー者
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'レビュー者',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _isEditMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _reviewerSearchController,
                                    decoration: const InputDecoration(
                                      hintText: '検索...',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    onSubmitted: (_) => _selectUser(false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    onPressed: () => _selectUser(false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B4A6B),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      '検索',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedReviewer != null) ...[
                            const SizedBox(height: 8),
                            Chip(
                              avatar: CircleAvatar(
                                backgroundColor: Colors.blue.shade700,
                                radius: 12,
                                child: Text(
                                  _selectedReviewer!.name[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              label: Text(
                                _selectedReviewer!.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedReviewer = null;
                                });
                              },
                              backgroundColor: Colors.blue.shade50,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.blue.shade200),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        _taskRecord!.reviewer.isEmpty
                            ? '未設定'
                            : _taskRecord!.reviewer,
                        style: const TextStyle(fontSize: 16),
                      ),
              ],
            ),
          ),
        ],
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
              if (_isEditMode) ...[
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ファイル追加'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_isEditMode) ...[
            if (_editingAttachments.isEmpty)
              const Text(
                '添付ファイルなし',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              )
            else
              Column(
                children: _editingAttachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeAttachment(index),
                            tooltip: '削除',
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ] else ...[
            if (_taskRecord!.attachments.isEmpty)
              const Text(
                '添付ファイルなし',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              )
            else
              Column(
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
          if (_isEditMode) ...[
            // 1行目: 案件No、取引先ID、検索ボタン
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _projectNoController,
                    decoration: const InputDecoration(
                      labelText: '案件No',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _clientIdController,
                    decoration: const InputDecoration(
                      labelText: '取引先ID',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _searchProjects,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B4A6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('検索'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 2行目: 案件名、取引先名、入力解除ボタン
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(
                      labelText: '案件名',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _clientNameController,
                    decoration: const InputDecoration(
                      labelText: '取引先名',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _clearProjectInfo,
                    label: const Text('入力解除', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // 表示モード
            Row(
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isSaving) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          if (!_isEditMode)
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
          if (_isEditMode) ...[
            SizedBox(
              width: 140,
              height: 45,
              child: OutlinedButton(
                onPressed: _toggleEditMode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B4A6B),
                  side: const BorderSide(color: Color(0xFF3B4A6B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              height: 45,
              child: ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: 140,
              height: 45,
              child: ElevatedButton(
                onPressed: _toggleEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B4A6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('編集', style: TextStyle(fontSize: 16)),
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
                child: const Text('削除', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ユーザー選択ダイアログ
class _UserSelectionDialog extends StatelessWidget {
  final List<KintoneUser> users;
  final String searchQuery;

  const _UserSelectionDialog({required this.users, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF3B4A6B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      searchQuery.isEmpty ? 'ユーザー一覧' : '検索結果: "$searchQuery"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'ユーザーが見つかりませんでした',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : '?',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        '${user.code}${user.email.isNotEmpty ? " • ${user.email}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(user),
                      hoverColor: Colors.blue.shade50,
                    );
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 案件選択ダイアログ
class _ProjectSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _ProjectSelectionDialog({required this.projects});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF3B4A6B),
              child: const Row(
                children: [
                  Icon(Icons.business, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '案件選択',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ListTile(
                    title: Text(project['案件名']?['value']?.toString() ?? ''),
                    subtitle: Text(
                      '取引先: ${project['取引先名']?['value']?.toString() ?? ''}',
                    ),
                    onTap: () => Navigator.of(context).pop(project),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

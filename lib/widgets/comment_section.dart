import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../models/user.dart';
import '../services/kintone_service.dart';

class CommentSection extends StatefulWidget {
  final String recordId;

  const CommentSection({super.key, required this.recordId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final KintoneService _kintoneService = KintoneService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Comment> _comments = [];
  List<Mention> _selectedMentions = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _kintoneService.getComments(widget.recordId);
      setState(() {
        _comments = comments;
        _isLoading = false;
        _errorMessage = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showUserSearchDialog() async {
    final searchQuery = _searchController.text.trim();

    // ローディング表示
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
      // ユーザー一覧を取得
      final users = await _kintoneService.getUsers();

      // 検索クエリでフィルタリング
      final filteredUsers = users
          .where((user) => user.matches(searchQuery))
          .toList();

      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // ユーザー選択ダイアログを表示
      final selectedUser = await showDialog<KintoneUser>(
        context: context,
        builder: (context) => _UserSelectionDialog(
          users: filteredUsers,
          searchQuery: searchQuery,
        ),
      );

      if (selectedUser != null) {
        setState(() {
          // 重複チェック
          if (!_selectedMentions.any((m) => m.user.code == selectedUser.code)) {
            _selectedMentions.add(Mention(user: selectedUser));
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      // ローディングを閉じる
      Navigator.of(context).pop();

      // エラー表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('エラー'),
            ],
          ),
          content: Text('ユーザーの取得に失敗しました。\n\n$e'),
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

  void _removeMention(int index) {
    setState(() {
      _selectedMentions.removeAt(index);
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コメントを入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _kintoneService.addComment(
        widget.recordId,
        text,
        mentions: _selectedMentions.isNotEmpty ? _selectedMentions : null,
      );

      _commentController.clear();
      setState(() {
        _selectedMentions.clear();
      });

      await _loadComments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コメントを送信しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'コメント',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_comments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // コメントリスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'コメントの読み込みに失敗しました',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _loadComments();
                            },
                            child: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'まだコメントがありません',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      return _buildCommentItem(_comments[index]);
                    },
                  ),
          ),

          // コメント入力欄
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 宛先検索エリア
                const Text(
                  '宛先',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ユーザー名で検索...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _showUserSearchDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _showUserSearchDialog,
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

                // 選択されたメンション表示
                if (_selectedMentions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMentions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final mention = entry.value;
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.blue.shade700,
                          child: Text(
                            mention.user.name.isNotEmpty
                                ? mention.user.name[0]
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        label: Text(mention.user.name),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeMention(index),
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),

                // コメント入力
                const Text(
                  'コメント入力欄',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        minLines: 1,
                        enabled: !_isSending,
                        decoration: InputDecoration(
                          hintText: 'コメントを入力...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B4A6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('送信'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            radius: 20,
            child: Text(
              comment.creator.name.isNotEmpty ? comment.creator.name[0] : '?',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.creator.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    comment.text,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ユーザー選択ダイアログ
class _UserSelectionDialog extends StatelessWidget {
  final List<KintoneUser> users;
  final String searchQuery;

  const _UserSelectionDialog({required this.users, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B4A6B),
                borderRadius: const BorderRadius.only(
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

            // ユーザーリスト
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
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

            // フッター
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

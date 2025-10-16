import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';
import '../models/task_record.dart';
import '../models/comment.dart';

class KintoneService {
  final Env _env = Env();

  Future<TaskRecord> getRecord(String recordId) async {
    final String? baseUrl = _env.baseUrl;
    final String? apiToken = _env.apiToken;
    final String? appId = _env.id;

    if (baseUrl == null || apiToken == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    // URIをクエリパラメータ付きで正しく構築
    final uri = Uri.parse(
      baseUrl + 'record.json',
    ).replace(queryParameters: {'app': appId, 'id': recordId});

    try {
      final response = await http
          .get(uri, headers: {'X-Cybozu-API-Token': apiToken})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return TaskRecord.fromKintoneJson(data['record']);
      } else {
        // エラー詳細を表示
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';

        // 404エラーまたはレコードが存在しないエラーの場合
        if (response.statusCode == 404 || code == 'GAIA_RE01') {
          throw Exception('そのレコードは存在しません');
        }

        throw Exception(
          'レコードの取得に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('API呼び出しエラー: $e');
    }
  }

  Future<void> deleteRecord(String recordId) async {
    final String? baseUrl = _env.baseUrl;
    final String? apiToken = _env.apiToken;
    final String? appId = _env.id;

    if (baseUrl == null || apiToken == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'records.json');

    try {
      final response = await http
          .delete(
            uri,
            headers: {
              'X-Cybozu-API-Token': apiToken,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'app': appId,
              'ids': [int.parse(recordId)],
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'レコードの削除に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('削除API呼び出しエラー: $e');
    }
  }

  // コメント取得
  Future<List<Comment>> getComments(String recordId) async {
    final String? baseUrl = _env.baseUrl;
    final String? apiToken = _env.apiToken;
    final String? appId = _env.id;

    if (baseUrl == null || apiToken == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'record/comments.json').replace(
      queryParameters: {
        'app': appId,
        'record': recordId,
        'order': 'asc', // 古い順（チャット形式）
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'X-Cybozu-API-Token': apiToken})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> commentsJson = data['comments'] ?? [];
        return commentsJson
            .map((json) => Comment.fromKintoneJson(json))
            .toList();
      } else {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'コメントの取得に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('コメント取得API呼び出しエラー: $e');
    }
  }

  // コメント追加
  Future<void> addComment(String recordId, String commentText) async {
    final String? baseUrl = _env.baseUrl;
    final String? apiToken = _env.apiToken;
    final String? appId = _env.id;

    if (baseUrl == null || apiToken == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'record/comment.json');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'X-Cybozu-API-Token': apiToken,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'app': appId,
              'record': recordId,
              'comment': {'text': commentText, 'mentions': []},
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'コメントの投稿に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('コメント投稿API呼び出しエラー: $e');
    }
  }
}

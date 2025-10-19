import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../env.dart';
import '../models/task_record.dart';
import '../models/comment.dart';
import '../models/user.dart';
import 'auth_manager.dart';

class KintoneService {
  final Env _env = Env();
  final AuthManager _authManager = AuthManager();

  // 認証ヘッダーを取得
  Map<String, String> _getAuthHeaders() {
    final headers = <String, String>{};

    if (_authManager.useBasicAuth && _authManager.basicAuthToken != null) {
      // Basic認証を使用
      headers['X-Cybozu-Authorization'] = _authManager.basicAuthToken!;
    } else {
      // APIトークン認証を使用
      final apiToken = _env.apiToken;
      if (apiToken != null) {
        headers['X-Cybozu-API-Token'] = apiToken;
      }
    }

    return headers;
  }

  Future<TaskRecord> getRecord(String recordId) async {
    final String? baseUrl = _env.baseUrl;
    final String? appId = _env.id;

    if (baseUrl == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(
      baseUrl + 'record.json',
    ).replace(queryParameters: {'app': appId, 'id': recordId});

    try {
      final response = await http
          .get(uri, headers: _getAuthHeaders())
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
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';

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
    final String? appId = _env.id;

    if (baseUrl == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'records.json');

    try {
      final headers = _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http
          .delete(
            uri,
            headers: headers,
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
    final String? appId = _env.id;

    if (baseUrl == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'record/comments.json').replace(
      queryParameters: {'app': appId, 'record': recordId, 'order': 'asc'},
    );

    try {
      final response = await http
          .get(uri, headers: _getAuthHeaders())
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

  // コメント追加（メンション対応）
  Future<void> addComment(
    String recordId,
    String commentText, {
    List<Mention>? mentions,
  }) async {
    final String? baseUrl = _env.baseUrl;
    final String? appId = _env.id;

    if (baseUrl == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'record/comment.json');

    try {
      final headers = _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      // メンション情報を構築
      final mentionsList = mentions?.map((m) => m.toJson()).toList() ?? [];

      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({
              'app': appId,
              'record': recordId,
              'comment': {'text': commentText, 'mentions': mentionsList},
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

  // ユーザー一覧を取得
  Future<List<KintoneUser>> getUsers() async {
    final String? domain = _env.domain;

    if (domain == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse('https://$domain/v1/users.json');

    try {
      final response = await http
          .get(uri, headers: _getAuthHeaders())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> usersJson = data['users'] ?? [];
        return usersJson.map((json) => KintoneUser.fromJson(json)).toList();
      } else {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'ユーザーの取得に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('ユーザー取得API呼び出しエラー: $e');
    }
  }

  // ファイルをダウンロード
  Future<String> downloadFile(String fileKey, String fileName) async {
    final String? baseUrl = _env.baseUrl;

    if (baseUrl == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(
      baseUrl + 'file.json',
    ).replace(queryParameters: {'fileKey': fileKey});

    try {
      // まずファイルをダウンロード
      final response = await http
          .get(uri, headers: _getAuthHeaders())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('リクエストがタイムアウトしました');
            },
          );

      if (response.statusCode == 200) {
        // Windowsのダウンロードフォルダパスを取得
        String? downloadsPath;

        if (Platform.isWindows) {
          // Windowsの場合は環境変数からダウンロードフォルダを取得
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            downloadsPath = '$userProfile\\Downloads';
          }
        } else {
          // その他のプラットフォームの場合
          final directory = await getDownloadsDirectory();
          downloadsPath = directory?.path;
        }

        if (downloadsPath == null) {
          throw Exception('ダウンロードフォルダが見つかりません');
        }

        // ダウンロードフォルダが存在するか確認
        final downloadsDir = Directory(downloadsPath);
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }

        // ファイルパスを作成
        String filePath = '$downloadsPath${Platform.pathSeparator}$fileName';

        // 同名ファイルが存在する場合、連番を付ける
        int counter = 1;
        while (File(filePath).existsSync()) {
          final extension = fileName.contains('.')
              ? fileName.substring(fileName.lastIndexOf('.'))
              : '';
          final nameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          filePath =
              '$downloadsPath${Platform.pathSeparator}${nameWithoutExt}_$counter$extension';
          counter++;
        }

        // ファイルを保存
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        return filePath;
      } else {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'ファイルのダウンロードに失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('ファイルダウンロードAPI呼び出しエラー: $e');
    }
  }
}

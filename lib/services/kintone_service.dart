import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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

  // レコードを更新
  Future<void> updateRecord(
    String recordId,
    Map<String, dynamic> record,
  ) async {
    final String? baseUrl = _env.baseUrl;
    final String? appId = _env.id;

    if (baseUrl == null || appId == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'record.json');

    try {
      final headers = _getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http
          .put(
            uri,
            headers: headers,
            body: json.encode({'app': appId, 'id': recordId, 'record': record}),
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
          'レコードの更新に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('更新API呼び出しエラー: $e');
    }
  }

  // 案件アプリからレコードを検索（仮実装 - 案件アプリのIDが必要）
  Future<List<Map<String, dynamic>>> searchProjects({
    String? projectNo,
    String? projectName,
    String? clientId,
    String? clientName,
  }) async {
    final String? baseUrl = _env.baseUrl;
    // TODO: 案件アプリのIDを環境変数から取得するか、直接指定
    const projectAppId = '6'; // 案件アプリのID（要変更）

    if (baseUrl == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    // 検索クエリを構築
    List<String> queryParts = [];
    if (projectNo != null && projectNo.isNotEmpty) {
      queryParts.add('案件No like "$projectNo"');
    }
    if (projectName != null && projectName.isNotEmpty) {
      queryParts.add('案件名 like "$projectName"');
    }
    if (clientId != null && clientId.isNotEmpty) {
      queryParts.add('取引先ID like "$clientId"');
    }
    if (clientName != null && clientName.isNotEmpty) {
      queryParts.add('取引先名 like "$clientName"');
    }

    final query = queryParts.isEmpty ? '' : queryParts.join(' and ');

    final uri = Uri.parse(baseUrl + 'records.json').replace(
      queryParameters: {
        'app': projectAppId,
        if (query.isNotEmpty) 'query': query,
      },
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
        final List<dynamic> recordsJson = data['records'] ?? [];
        return recordsJson.cast<Map<String, dynamic>>();
      } else {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          '案件の検索に失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('案件検索API呼び出しエラー: $e');
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
      // ファイルをダウンロード
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
        String downloadsPath;

        if (Platform.isWindows) {
          // Windows環境変数からユーザープロファイルを取得
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile == null) {
            throw Exception('ユーザープロファイルが見つかりません');
          }
          downloadsPath = '$userProfile\\Downloads';
        } else if (Platform.isMacOS || Platform.isLinux) {
          // macOS/Linux環境変数からホームディレクトリを取得
          final home = Platform.environment['HOME'];
          if (home == null) {
            throw Exception('ホームディレクトリが見つかりません');
          }
          downloadsPath = '$home/Downloads';
        } else {
          throw Exception('サポートされていないプラットフォームです');
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

  // ファイルをアップロード
  Future<String> uploadFile(String filePath) async {
    final String? baseUrl = _env.baseUrl;

    if (baseUrl == null) {
      throw Exception('環境変数が正しく設定されていません');
    }

    final uri = Uri.parse(baseUrl + 'file.json');
    final file = File(filePath);

    if (!file.existsSync()) {
      throw Exception('ファイルが見つかりません');
    }

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getAuthHeaders());

      final fileName = filePath.split(Platform.pathSeparator).last;
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('リクエストがタイムアウトしました');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['fileKey'] ?? '';
      } else {
        final errorBody = json.decode(response.body);
        final code = errorBody['code'] ?? 'UNKNOWN';
        final message = errorBody['message'] ?? 'エラーが発生しました';
        throw Exception(
          'ファイルのアップロードに失敗しました: ${response.statusCode}\ncode = $code\n$message',
        );
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('ファイルアップロードAPI呼び出しエラー: $e');
    }
  }
}

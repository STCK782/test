class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  String? _username;
  String? _basicAuthToken;
  bool _useBasicAuth = false;

  // ログイン情報を設定
  void setCredentials(String username, String basicAuthToken) {
    _username = username;
    _basicAuthToken = basicAuthToken;
    _useBasicAuth = true;
  }

  // APIトークン認証に切り替え
  void useApiToken() {
    _useBasicAuth = false;
  }

  // 基本認証を使用するかどうか
  bool get useBasicAuth => _useBasicAuth;

  // ユーザーネームを取得
  String? get username => _username;

  // Basic認証トークンを取得
  String? get basicAuthToken => _basicAuthToken;

  // ログイン状態をクリア
  void clearCredentials() {
    _username = null;
    _basicAuthToken = null;
    _useBasicAuth = false;
  }
}

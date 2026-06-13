import 'package:shared_preferences/shared_preferences.dart';

/// JWT token va foydalanuvchi ma'lumotlarini qurilmada saqlaydi
/// (shared_preferences). Token xotirada ham keshlanadi — Dio interceptor
/// uni sinxron o'qiy oladi (har so'rovda diskka bormaslik uchun).
///
/// SOLID: yagona mas'uliyat — faqat token persistensiyasi. Boshqa qatlamlar
/// (auth repo, dio) shu yagona manbaga tayanadi.
class TokenStorage {
  static const _kToken = 'auth_access_token';
  static const _kUserId = 'auth_user_id';
  static const _kEmail = 'auth_email';
  static const _kFullName = 'auth_full_name';

  final SharedPreferences _prefs;

  /// Xotiradagi kesh — interceptor sinxron o'qishi uchun.
  String? _cachedToken;

  TokenStorage(this._prefs) {
    _cachedToken = _prefs.getString(_kToken);
  }

  /// Ilova ishga tushganda bir marta chaqiriladi.
  static Future<TokenStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TokenStorage(prefs);
  }

  String? get token => _cachedToken;

  bool get isLoggedIn => (_cachedToken ?? '').isNotEmpty;

  String? get userId => _prefs.getString(_kUserId);
  String? get email => _prefs.getString(_kEmail);
  String? get fullName => _prefs.getString(_kFullName);

  Future<void> save({
    required String token,
    required String userId,
    required String email,
    String fullName = '',
  }) async {
    _cachedToken = token;
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kUserId, userId);
    await _prefs.setString(_kEmail, email);
    await _prefs.setString(_kFullName, fullName);
  }

  Future<void> clear() async {
    _cachedToken = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kFullName);
  }
}

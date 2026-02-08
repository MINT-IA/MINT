import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing JWT authentication tokens and user session
/// Uses SharedPreferences for simple MVP - stores JWT tokens securely
class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _displayNameKey = 'display_name';

  /// Store auth token after login/register
  static Future<void> saveToken(
    String token,
    String userId,
    String email, {
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    if (displayName != null) {
      await prefs.setString(_displayNameKey, displayName);
    }
  }

  /// Get stored token (null if not logged in)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get stored email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Get stored display name
  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear token (logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_displayNameKey);
  }
}

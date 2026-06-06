import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../models.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(ref.read(apiClientProvider));
  controller.restore();
  return controller;
});

@immutable
class AuthState {
  const AuthState({
    this.isLoading = true,
    this.user,
    this.profile,
    this.accessToken,
    this.refreshToken,
    this.hasVideoConsent = false,
    this.error,
  });

  final bool isLoading;
  final UserProfile? user;
  final GolferProfile? profile;
  final String? accessToken;
  final String? refreshToken;
  final bool hasVideoConsent;
  final String? error;

  bool get isAuthenticated => accessToken != null && user != null;

  bool get isOnboarded {
    return profile?.handedness != null &&
        profile?.skillLevel != null &&
        (profile?.goals.isNotEmpty ?? false) &&
        hasVideoConsent;
  }

  AuthState copyWith({
    bool? isLoading,
    UserProfile? user,
    GolferProfile? profile,
    String? accessToken,
    String? refreshToken,
    bool? hasVideoConsent,
    String? error,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearSession ? null : user ?? this.user,
      profile: clearSession ? null : profile ?? this.profile,
      accessToken: clearSession ? null : accessToken ?? this.accessToken,
      refreshToken: clearSession ? null : refreshToken ?? this.refreshToken,
      hasVideoConsent: clearSession ? false : hasVideoConsent ?? this.hasVideoConsent,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController(this._api);

  final ApiClient _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AuthState state = const AuthState();

  Future<void> restore() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (accessToken == null || refreshToken == null) {
        state = state.copyWith(isLoading: false, clearSession: true);
        notifyListeners();
        return;
      }
      final me = await _api.getMe(accessToken);
      final consents = await _api.getConsents(accessToken);
      state = AuthState(
        isLoading: false,
        user: me.user,
        profile: me.profile,
        accessToken: accessToken,
        refreshToken: refreshToken,
        hasVideoConsent: consents.any((consent) => consent.consentType == 'video_processing'),
      );
    } catch (_) {
      await _storage.deleteAll();
      state = state.copyWith(isLoading: false, clearSession: true);
    }
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    await _authenticate(() => _api.register(email: email, password: password));
  }

  Future<void> login(String email, String password) async {
    await _authenticate(() => _api.login(email: email, password: password));
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    final token = state.accessToken;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final me = await _api.updateProfile(token, payload);
      state = state.copyWith(isLoading: false, user: me.user, profile: me.profile);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
    }
    notifyListeners();
  }

  Future<void> acceptVideoConsent() async {
    final token = state.accessToken;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      await _api.acceptVideoConsent(token);
      state = state.copyWith(isLoading: false, hasVideoConsent: true);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
    }
    notifyListeners();
  }

  Future<void> logout() async {
    final refreshToken = state.refreshToken;
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {
        // Local logout must still clear credentials if the API is unreachable.
      }
    }
    await _storage.deleteAll();
    state = state.copyWith(isLoading: false, clearSession: true, clearError: true);
    notifyListeners();
  }

  Future<void> _authenticate(Future<AuthPayload> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final payload = await action();
      await _storage.write(key: 'access_token', value: payload.accessToken);
      await _storage.write(key: 'refresh_token', value: payload.refreshToken);
      state = AuthState(
        isLoading: false,
        user: payload.user,
        accessToken: payload.accessToken,
        refreshToken: payload.refreshToken,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
    }
    notifyListeners();
  }

  String _message(Object error) {
    final value = error.toString();
    if (value.contains('SocketException') || value.contains('Connection refused')) {
      return 'API unavailable. Start the backend and try again.';
    }
    return 'Request failed. Check the details and try again.';
  }
}

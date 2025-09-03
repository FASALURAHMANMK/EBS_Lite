import 'dart:async';

/// Simple global auth event bus to broadcast logout/invalidation events
class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  final StreamController<void> _logoutController = StreamController.broadcast();

  Stream<void> get onLogout => _logoutController.stream;

  void broadcastLogout() {
    if (!_logoutController.isClosed) {
      _logoutController.add(null);
    }
  }

  void dispose() {
    _logoutController.close();
  }
}


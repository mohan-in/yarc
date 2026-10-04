import 'package:flutter/foundation.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/repositories/user_repository.dart';

/// Notifier for managing user profile details and state.
class UserNotifier extends ChangeNotifier {
  UserRepository? _repository;

  RedditorInfo? _userInfo;
  bool _isLoading = false;
  String? _errorMessage;

  RedditorInfo? get userInfo => _userInfo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Injected via ProxyProvider update callback.
  // ignore: use_setters_to_change_properties
  void setRepository(UserRepository repository) {
    _repository = repository;
  }

  /// Fetches user profile info by [username].
  Future<RedditorInfo?> fetchUser(String username) async {
    if (_repository == null) {
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return _userInfo = await _repository!.fetchUser(username);
    } on Exception catch (e) {
      _errorMessage = e.toString();
      _userInfo = null;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _userInfo = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}

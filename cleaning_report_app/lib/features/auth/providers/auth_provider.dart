import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/gas_api_client.dart';

// API Client Provider
final apiClientProvider = Provider<GasApiClient>((ref) => GasApiClient());

// Auth State
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

// Auth Notifier
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  final GasApiClient _api;

  AuthNotifier(this._api) : super(const AsyncValue.data(false));

  Future<bool> verifyPin(String pin) async {
    state = const AsyncValue.loading();
    
    final result = await _api.verifyPin(pin);
    
    if (result['success'] == true) {
      state = const AsyncValue.data(true);
      return true;
    } else {
      state = AsyncValue.error(result['message'] ?? 'Invalid PIN', StackTrace.current);
      return false;
    }
  }

  void logout() {
    state = const AsyncValue.data(false);
  }
}

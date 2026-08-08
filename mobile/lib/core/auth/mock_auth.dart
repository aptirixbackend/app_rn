import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final mockAuthProvider = Provider<MockAuth>((ref) => MockAuth());

/// 'owner' (chose Post a Home) or 'searcher' (chose Search / default).
final userRoleProvider = FutureProvider<String>((ref) async {
  final goal = await ref.read(mockAuthProvider).goal();
  return goal == 'post' ? 'owner' : 'searcher';
});

final userNameProvider =
    FutureProvider<String?>((ref) => ref.read(mockAuthProvider).name());
final userEmailProvider =
    FutureProvider<String?>((ref) => ref.read(mockAuthProvider).email());
final userPhoneProvider =
    FutureProvider<String?>((ref) => ref.read(mockAuthProvider).phone());
final userCityProvider =
    FutureProvider<String?>((ref) => ref.read(mockAuthProvider).city());
final userAvatarProvider =
    FutureProvider<String?>((ref) => ref.read(mockAuthProvider).avatar());

/// Temporary local auth for development — no SMS needed.
/// OTP is a fixed [demoOtp]. Login + "onboarding done" flags persist locally
/// (shared_preferences), so a returning user who already filled their details
/// goes straight to Home. Swap for real Supabase auth at the end.
class MockAuth {
  static const demoOtp = '123456';

  /// Ready-made demo logins (OTP is always [demoOtp]). Entering one of these
  /// numbers skips onboarding and lands on Home in the right role.
  /// value = (display name, goal): 'post' → property owner, 'search' → buyer.
  static const demoAccounts = <String, (String, String)>{
    '+919000000001': ('Sneha Reddy', 'post'),
    '+919000000002': ('Rahul Verma', 'search'),
  };

  static const _kLoggedIn = 'mock_logged_in';
  static const _kPhone = 'mock_phone';
  static const _kOnboarded = 'mock_onboarded';
  static const _kName = 'mock_name';
  static const _kGoal = 'mock_goal';
  static const _kUserId = 'mock_user_id';
  static const _kEmail = 'mock_email';
  static const _kCity = 'mock_city';
  static const _kAvatar = 'mock_avatar';

  /// Stable per-device id used as the customer/user id for favorites,
  /// leads and visits until real auth is wired in.
  Future<String> userId() async {
    final p = await _prefs;
    var id = p.getString(_kUserId);
    if (id == null) {
      id = 'u_${DateTime.now().microsecondsSinceEpoch}';
      await p.setString(_kUserId, id);
    }
    return id;
  }

  Future<String?> phone() async => (await _prefs).getString(_kPhone);

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  bool verifyOtp(String code) => code == demoOtp;

  Future<bool> isLoggedIn() async => (await _prefs).getBool(_kLoggedIn) ?? false;
  Future<bool> isOnboarded() async =>
      (await _prefs).getBool(_kOnboarded) ?? false;
  Future<String?> name() async => (await _prefs).getString(_kName);
  Future<String?> goal() async => (await _prefs).getString(_kGoal);
  Future<String?> email() async => (await _prefs).getString(_kEmail);
  Future<String?> city() async => (await _prefs).getString(_kCity);
  Future<String?> avatar() async => (await _prefs).getString(_kAvatar);

  /// Update editable profile fields (Edit Profile screen).
  Future<void> setProfile({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? avatar,
  }) async {
    final p = await _prefs;
    if (name != null) await p.setString(_kName, name);
    if (email != null) await p.setString(_kEmail, email);
    if (phone != null) await p.setString(_kPhone, phone);
    if (city != null) await p.setString(_kCity, city);
    if (avatar != null) await p.setString(_kAvatar, avatar);
  }

  Future<void> login(String phone) async {
    final p = await _prefs;
    await p.setBool(_kLoggedIn, true);
    await p.setString(_kPhone, phone);
  }

  /// Bind the local session to the backend-authenticated user: the user id
  /// becomes the backend's uuid (so favorites/leads/visits key off the real
  /// user), and phone/name are cached for the profile UI.
  Future<void> setSession({String? userId, String? phone, String? name}) async {
    final p = await _prefs;
    await p.setBool(_kLoggedIn, true);
    if (userId != null && userId.isNotEmpty) await p.setString(_kUserId, userId);
    if (phone != null && phone.isNotEmpty) await p.setString(_kPhone, phone);
    if (name != null && name.isNotEmpty) await p.setString(_kName, name);
  }

  Future<void> setGoal(String goal) async =>
      (await _prefs).setString(_kGoal, goal);

  /// If [phoneE164] is a known [demoAccounts] entry, pre-fills its profile
  /// (goal + onboarded + name) so login lands straight on Home in that role.
  /// Returns true when a demo account was applied.
  Future<bool> applyDemoAccount(String phoneE164) async {
    final acc = demoAccounts[phoneE164];
    if (acc == null) return false;
    final p = await _prefs;
    await p.setString(_kGoal, acc.$2);
    await p.setString(_kName, acc.$1);
    await p.setBool(_kOnboarded, true);
    return true;
  }

  Future<void> setOnboarded({String? name}) async {
    final p = await _prefs;
    await p.setBool(_kOnboarded, true);
    if (name != null && name.isNotEmpty) await p.setString(_kName, name);
  }

  Future<void> logout() async {
    final p = await _prefs;
    await p.remove(_kLoggedIn);
    await p.remove(_kOnboarded);
    await p.remove(_kPhone);
    await p.remove(_kName);
    await p.remove(_kGoal);
  }
}

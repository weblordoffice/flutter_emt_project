import 'package:emtrack/models/role/profile_model.dart';
import 'package:emtrack/models/user_models.dart';
import 'package:get/get.dart';
import 'package:emtrack/routes/app_pages.dart';
import '../services/auth_service.dart';
import '../services/change_account_service.dart';
import '../utils/secure_storage.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;
  final showPassword = false.obs;
  final user = Rxn<UserModel>();
  final errorMessage = ''.obs;

  RxString userRole = "".obs;
  RxString userName = "".obs;

  @override
  void onInit() {
    super.onInit();
    loadLocalUser();
  }

  Future<void> loadLocalUser() async {
    userRole.value = await SecureStorage.getUserProfileRole() ?? "";
    userName.value = await SecureStorage.getUserProfileName() ?? "";
  }

  Future<UserModel?> login(String username, String password) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final UserModel? user = await AuthService.login(username, password);

      if (user == null) {
        errorMessage.value = "Invalid username or password";
        return null;
      }

      await SecureStorage.saveUserName(username);
      await SecureStorage.saveToken("logged_in");

      // ✅ Step 1: Profile save karo
      await getUserProfile();

      // ✅ Step 2: Default account + location save karo (HOME pe data dikhne ke liye)
      await _saveDefaultAccountAndLocation();

      Get.offAllNamed(AppPages.HOME);
      return user;
    } catch (e) {
      errorMessage.value = "Something went wrong";
      print("Login error: $e");
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Login ke baad pehla account aur pehli location SecureStorage mein save karo ───
  Future<void> _saveDefaultAccountAndLocation() async {
    try {
      final accountService = ChangeAccountService();

      // Accounts fetch karo
      final accounts = await accountService.fetchParentAccounts();
      if (accounts.isEmpty) {
        print("⚠️ No accounts found");
        return;
      }

      final firstAccount = accounts.first;
      final accountId   = firstAccount.parentAccountId.toString();
      final accountName = firstAccount.accountName;

      await SecureStorage.saveParentAccount(id: accountId, name: accountName);
      print("✅ Default account saved: $accountName ($accountId)");

      // Locations fetch karo
      final locations = await accountService.fetchLocations(firstAccount.parentAccountId);
      if (locations.isEmpty) {
        print("⚠️ No locations found — using placeholder");
        await SecureStorage.saveLocation(id: '0', name: 'All Locations');
        return;
      }

      final firstLocation = locations.first;
      await SecureStorage.saveLocation(
        id:   firstLocation.locationId.toString(),
        name: firstLocation.locationName,
      );
      print("✅ Default location saved: ${firstLocation.locationName} (${firstLocation.locationId})");

    } catch (e) {
      print("❌ _saveDefaultAccountAndLocation error: $e");
      // Error pe bhi crash mat karo — login continue hoga
    }
  }

  Future<UserProfile?> getUserProfile() async {
    try {
      isLoading.value = true;

      final UserProfile? userData = await AuthService.getUserprofile();
      if (userData == null) return null;

      await SecureStorage.saveUserProfileRole(userData.userRole ?? "");
      await SecureStorage.saveUserProfileName(
        "${userData.firstName ?? ""} ${userData.lastName ?? ""}".trim(),
      );

      userRole.value = userData.userRole ?? "";
      userName.value = "${userData.firstName ?? ""} ${userData.lastName ?? ""}".trim();

      return userData;
    } catch (e) {
      errorMessage.value = "Failed to load profile";
      print("getUserProfile error: $e");
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearToken();
    await SecureStorage.clearCookie();
    await SecureStorage.saveUserProfileRole("");
    await SecureStorage.saveUserProfileName("");
    // ✅ Account + Location bhi clear karo logout pe
    await SecureStorage.saveParentAccount(id: '', name: '');
    await SecureStorage.saveLocation(id: '', name: '');

    user.value = null;
    Get.offAllNamed(AppPages.LOGIN);
  }
}
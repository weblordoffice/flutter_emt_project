import 'dart:convert';
import 'package:emtrack/models/statical_model.dart';
import 'package:emtrack/services/api_constants.dart';
import 'package:emtrack/services/api_service.dart';
import 'package:emtrack/services/global_logout_handler.dart';
import 'package:emtrack/utils/secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../models/home_model.dart';

class HomeService {

  // ─── VEHICLE RAW LIST ────────────────────────────────────────────────────────
  // ✅ FIX: timeStamp int 0 bhejo — float "0.0" bhejne pe server 500 deta tha
  //         "Error converting data type varchar to decimal"
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>?> fetchVehicleRawList(
      String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) return null;

      // ✅ timeStamp = 0 (int) — float nahi
      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Vehicle/GetVehicleByUser/$parentAccountId/0?timeStamp=0",
      );

      final resp = await http.get(
        uri,
        headers: {"Accept": "application/json", "Cookie": cookie},
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['didError'] == true) return null;
        final List list = json['model'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return null;
    } catch (e) {
      print("fetchVehicleRawList error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchTyreRawList(
      String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null) return null;

      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Tire/GetTiresByAccount/$parentAccountId",
      );

      final resp = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "Cookie": cookie},
      );

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        Get.find<GlobalLogoutHandler>().forceLogout();
        return null;
      }

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final List list = json['model'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return null;
    } catch (e) {
      print("fetchTyreRawList error: $e");
      return null;
    }
  }

  // ─── FETCH HOME DATA ─────────────────────────────────────────────────────────
  // Server /api/Home kabhi plain GUID string deta hai (e.g. "8f9a513e-...")
  // Jab plain string aaye tab SecureStorage se HomeModel build karo
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<HomeModel?> fetchHomeData() async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) {
        throw Exception("Session expired. Please login again.");
      }

      final uri = Uri.parse("${ApiConstants.baseUrl}/api/Home");
      final resp = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept":        "application/json",
          "Cookie":        cookie,
        },
      );

      print("DASHBOARD STATUS => ${resp.statusCode}");
      print("DASHBOARD BODY => ${resp.body}");

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        print("🔐 SESSION EXPIRED");
        Get.find<GlobalLogoutHandler>().forceLogout();
        return null;
      }

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);

        // ✅ Case 1: Plain GUID string — SecureStorage se HomeModel build karo
        if (decoded is String) {
          print("⚠️ Home API returned plain GUID — building HomeModel from local storage");
          return await _buildHomeModelFromLocal();
        }

        // ✅ Case 2: Proper JSON Map
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return HomeModel.fromJson(payload);
          }
        }

        return null;
      }

      return null;
    } catch (e) {
      print('HomeService.fetchHomeData error: $e');
      return null;
    }
  }

  // ─── SecureStorage se HomeModel build karo ───────────────────────────────────
  static Future<HomeModel?> _buildHomeModelFromLocal() async {
    try {
      final accountName  = await SecureStorage.getParentAccountName() ?? '';
      final locationName = await SecureStorage.getLocationName() ?? '';
      final userName     = await SecureStorage.getUserProfileName() ?? '';
      final userRole     = await SecureStorage.getUserProfileRole() ?? '';

      print("🏠 Building HomeModel from local => $accountName | $locationName | $userName");

      return HomeModel(
        username:            userName,
        parentAccount:       accountName,
        location:            locationName,
        role:                userRole,
        lastInspection:      '--',
        unsyncedInspections: 0,
        syncedInspections:   0,
        totalTyres:          0,
        vehicles:            0,
        appVersion:          '1.0',
        imageUrl:            '',
      );
    } catch (e) {
      print("_buildHomeModelFromLocal error: $e");
      return null;
    }
  }

  static Future<bool> syncInspections() async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) {
        throw Exception("Session expired. Please login again.");
      }

      final uri = Uri.parse("${ApiConstants.baseUrl}/inspections/sync");
      final resp = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept":        "application/json",
          "Cookie":        cookie,
        },
      );

      if (resp.statusCode == 200) return true;

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        Get.find<GlobalLogoutHandler>().forceLogout();
        return false;
      }

      return false;
    } catch (e) {
      print('HomeService.syncInspections error: $e');
      return false;
    }
  }

  // ✅ FIX: timeStamp int 0 — float nahi
  static Future<int> fetchTyreCountByAccount(String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null) return 0;

      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Tire/GetTiresByAccount/$parentAccountId",
      );

      final resp = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "Cookie": cookie},
      );

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        Get.find<GlobalLogoutHandler>().forceLogout();
        return 0;
      }

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final List list = json['model'] ?? [];
        return list.length;
      }

      return 0;
    } catch (e) {
      print("Tyre API exception $e");
      return 0;
    }
  }

  // ✅ FIX: timeStamp = 0 (int) in URL — float "0.0" se server 500 deta tha
  static Future<int> fetchVehicleCountByAccount(String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) return 0;

      // ✅ /0?timeStamp=0 — integer, float nahi
      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Vehicle/GetVehicleByUser/$parentAccountId/0?timeStamp=0",
      );

      print("🌐 URL => $uri");

      final resp = await http.get(
        uri,
        headers: {"Accept": "application/json", "Cookie": cookie},
      );

      print("📡 STATUS => ${resp.statusCode}");
      print("📦 BODY => ${resp.body}");

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['didError'] == true) {
          print("Backend Error => ${json['errorMessage']}");
          return 0;
        }
        final List list = json['model'] ?? [];
        return list.length;
      }

      return 0;
    } catch (e) {
      print("🔥 Vehicle API exception => $e");
      return 0;
    }
  }

  static Future<DashboardModel?> fetchReportDashboardHomeData() async {
    final parentAccountId = await SecureStorage.getParentAccountId();
    final getLocationId   = await SecureStorage.getLocationId();

    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) {
        throw Exception("Session expired. Please login again.");
      }

      final resp = await ApiService.postApi(
        endpoint: "/api/Report/GetReportDashboardData",
        body: {"accountIds": parentAccountId, "locationIds": getLocationId},
      );

      if (resp['model'] != null) {
        return DashboardModel.fromJson(resp["model"]);
      }

      return null;
    } catch (e) {
      print('HomeService.fetchReportDashboardHomeData error: $e');
      return null;
    }
  }
}
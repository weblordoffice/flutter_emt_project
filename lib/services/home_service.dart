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
          "Accept": "application/json",
          "Cookie": cookie,
        },
      );

      print("DASHBOARD STATUS => ${resp.statusCode}");
      print("DASHBOARD BODY => ${resp.body}");

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);

        if (decoded is String) {
          print(
            "⚠️ Home API returned plain String — not a Map. Skipping parse.",
          );
          return null;
        }

        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return HomeModel.fromJson(payload);
          }
        }

        return null;
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        print("🔐 SESSION EXPIRED");
        Get.find<GlobalLogoutHandler>().forceLogout();
        return null;
      }

      return null;
    } catch (e) {
      print('HomeService.fetchHomeData error: $e');
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
          "Accept": "application/json",
          "Cookie": cookie,
        },
      );

      print("SYNC STATUS => ${resp.statusCode}");
      print("SYNC BODY => ${resp.body}");

      if (resp.statusCode == 200) return true;

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        print("🔐 SESSION EXPIRED");
        Get.find<GlobalLogoutHandler>().forceLogout();
        return false;
      }

      return false;
    } catch (e) {
      print('HomeService.syncInspections error: $e');
      return false;
    }
  }

  static Future<int> fetchTyreCountByAccount(String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null) return 0;

      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Tire/GetTiresByAccount/$parentAccountId",
      );

      print("Tyre Count URL: $uri");

      final resp = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "Cookie": cookie},
      );

      print("Tyre Count STATUS: ${resp.statusCode}");
      print("Tyre Count BODY: ${resp.body}");

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await SecureStorage.clearCookie();
        Get.find<GlobalLogoutHandler>().forceLogout();
        return 0;
      }

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final List list = json['model'] ?? [];
        print("Tyre Count Result: ${list.length}");
        return list.length;
      }

      return 0;
    } catch (e) {
      print("Tyre API exception $e");
      return 0;
    }
  }

  static Future<int> fetchVehicleCountByAccount(String parentAccountId) async {
    try {
      final cookie = await SecureStorage.getCookie();
      if (cookie == null || cookie.isEmpty) return 0;

      const double timeStamp = 0.0;

      final uri = Uri.parse(
        "${ApiConstants.baseUrl}/api/Vehicle/GetVehicleByUser/"
        "$parentAccountId/0.0"
        "?timeStamp=$timeStamp",
      );

      print("Vehicle Count URL: $uri");

      final resp = await http.get(
        uri,
        headers: {"Accept": "application/json", "Cookie": cookie},
      );

      print("Vehicle Count STATUS: ${resp.statusCode}");
      print("Vehicle Count BODY: ${resp.body}");

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['didError'] == true) {
          print("Backend Error => ${json['errorMessage']}");
          return 0;
        }
        final List list = json['model'] ?? [];
        print("Vehicle Count Result: ${list.length}");
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
    final getLocationId = await SecureStorage.getLocationId();

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
        final model = resp["model"];
        return DashboardModel.fromJson(model);
      }

      return null;
    } catch (e) {
      print('HomeService.fetchReportDashboardHomeData error: $e');
      return null;
    }
  }
}

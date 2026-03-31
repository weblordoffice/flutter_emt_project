import 'dart:convert';
import 'package:emtrack/services/api_constants.dart';
import 'package:http/http.dart' as http;
import '../utils/secure_storage.dart';

class InstallTyreService {
  Future<bool> submitInspection(Map<String, dynamic> data) async {
    try {
      final cookie = await SecureStorage.getCookie();
      print("🔐 INSTALL COOKIE => $cookie");

      if (cookie == null || cookie.isEmpty) {
        throw Exception("Session expired. Please login again.");
      }

      // ✅ STEP 1: Pehle unwanted fields hata do
      data.remove("inspectionId");
      data.remove("removalReasonId");
      data.remove("rimDispositionId");
      data.remove("mountedRimId");
      data.remove("middleTread");
      data.remove("imagesLocation");

      // ✅ STEP 2: Date fix
      if (data.containsKey("inspectionDate") &&
          data["inspectionDate"] is DateTime) {
        data["inspectionDate"] =
        '${(data["inspectionDate"] as DateTime).toUtc().toIso8601String().split('.').first}Z';
      }

      final url = Uri.parse(
        "${ApiConstants.baseUrl}/api/Inspection/InstallTire",
      );
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Cookie": cookie,
      };

      print("📤 FINAL PAYLOAD => ${jsonEncode(data)}");

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      print("📡 STATUS: ${response.statusCode}");
      print("📥 BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded["didError"] == false) return true;
        throw Exception(
          decoded["errorMessage"] ?? "Backend returned an error without message.",
        );
      }

      if (response.statusCode == 401) {
        await SecureStorage.clearCookie();
        throw Exception("Session expired. Please login again.");
      }

      throw Exception(
        "Failed with status ${response.statusCode}: ${response.body}",
      );
    } catch (e) {
      print("❌ Install Tire API Error: $e");
      rethrow;
    }
  }
}
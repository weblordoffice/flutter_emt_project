import 'dart:convert';
import 'package:emtrack/services/api_constants.dart';
import 'package:emtrack/services/global_logout_handler.dart';
import 'package:emtrack/utils/secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class MasterDataService {
  Future<Map<String, dynamic>> fetchMasterData() async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/api/MasterData/GetMasterDataMobile',
    );

    print('📡 MASTER DATA URL: $url');

    final cookie = await SecureStorage.getCookie();
    print('🍪 COOKIE: $cookie');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (cookie != null) 'Cookie': cookie,
      },
    );

    print('📡 STATUS: ${response.statusCode}');
    print('📥 BODY: ${response.body}');
    print('📥 HEADERS: ${response.headers}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json['didError'] == true) {
        throw Exception(json['errorMessage'] ?? 'Unknown server error');
      }

      return json['model'];
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      print("🔐 SESSION EXPIRED");
      Get.find<GlobalLogoutHandler>().forceLogout();
      return fetchMasterData();
    }

    throw Exception('Master data failed (${response.statusCode})');
  }
}

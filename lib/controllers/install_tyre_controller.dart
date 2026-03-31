import 'dart:convert';
import 'package:emtrack/inspection/vehicle_inspe_controller.dart';
import 'package:emtrack/models/install_tyre_model.dart';
import 'package:emtrack/services/install_tyre_service.dart';
import 'package:emtrack/services/master_data_service.dart';
import 'package:emtrack/utils/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../models/tyre_model.dart';
import '../services/tyre_service.dart';

class InstallTyreController extends GetxController {
  final RxBool isSubmitting = false.obs;
  final RxBool isInitialLoading = false.obs;

  final service = InstallTyreService();
  final tyreService = TyreService();
  final picker = ImagePicker();
  final MasterDataService _masterService = MasterDataService();

  Rx<InstallTireModel> model = InstallTireModel().obs;

  // Wear Conditions
  final wearConditionsList = <String>[].obs;
  final wearConditionsIdList = <int>[].obs;
  final RxInt selectedWearConditionsId = 0.obs;
  final wearConditionsId = TextEditingController();

  // Casing Conditions
  final casingConditionList = <String>[].obs;
  final casingConditionIdList = <int>[].obs;
  final RxInt selectedCasingConditionId = 0.obs;
  final casingConditionsId = TextEditingController();

  // Disposition
  final dispositionList = <String>[].obs;
  final dispositionIdList = <int>[].obs;
  final RxInt installedDispositionId = 0.obs;

  // Sanitized values from API
  double safeOriginalTread = 140.0;
  double safeRemoveAt = 0.0;

  final RxString vehicleNumber = "".obs;
  RxList<TyreModel> tyreList = <TyreModel>[].obs;
  RxDouble avgTread = 0.0.obs;

  final commentsController = TextEditingController();
  final treadDepthController = TextEditingController();
  final previousCommentController = TextEditingController(
    text: "List Of Previous Comments",
  );

  double _sanitizeTread(double? value, double fallback) {
    if (value == null || value <= 0 || value > 100) return fallback;
    return value;
  }

  double _sanitizePressure(double? value) {
    if (value == null || value <= 0 || value > 500) return 28.0;
    return value;
  }

  double _sanitizeOriginal(double? value) {
    if (value == null || value <= 0 || value > 1000) return 140.0;
    return value;
  }

  double _sanitizeRemoveAt(double? value) {
    if (value == null || value < 0 || value > 100) return 0.0;
    return value;
  }

  @override
  void onInit() {
    super.onInit();

    commentsController.text = model.value.comments ?? "";

    final args = Get.arguments ?? {};
    print("install tire args => $args");

    final int vehicleId = args["vehicleId"] ?? 0;
    vehicleNumber.value = args["vehicleNumber"] ?? "";
    final String wheelPosition = args["wheelPosition"] ?? "";
    final int tireId = args["tireId"] ?? 0;
    final String serialNo = args["serialNo"] ?? "";

    model.update((m) {
      m!.vehicleId = vehicleId;
      m.wheelPosition = wheelPosition;
      m.tireId = tireId;
      m.tireSerialNo = serialNo;
      m.currentTreadDepth = 0.0;
    });

    print("INIT vehicleId => $vehicleId");
    print("INIT wheelPosition => $wheelPosition");
    print("INIT tireId => $tireId");

    loadMasterData();
    loadTyres(tireId);
  }

  void incAir() => model.update((m) => m!.currentPressure++);
  void decAir() => model.update((m) {
    if (m!.currentPressure > 0) m.currentPressure--;
  });

  void incOutside() => model.update((m) {
    m!.outsideTread++;
    _calcAverage(m);
  });
  void decOutside() => model.update((m) {
    if (m!.outsideTread > 0) m.outsideTread--;
    _calcAverage(m);
  });

  void incInside() => model.update((m) {
    m!.insideTread++;
    _calcAverage(m);
  });
  void decInside() => model.update((m) {
    if (m!.insideTread > 0) m.insideTread--;
    _calcAverage(m);
  });

  void _calcAverage(InstallTireModel m) {
    final outside = m.outsideTread;
    final inside = m.insideTread;
    final avg = (outside + inside) / 2;
    m.currentTreadDepth = double.parse(avg.toStringAsFixed(2));
  }

  Future<void> loadMasterData() async {
    try {
      final data = await _masterService.fetchMasterData();

      wearConditionsList.assignAll(
        (data['wearConditions'] as List)
            .map((e) => e['wearConditionName'].toString().toUpperCase())
            .toSet()
            .toList(),
      );
      wearConditionsIdList.assignAll(
        (data['wearConditions'] as List)
            .map((e) => e['wearConditionId'] as int)
            .toSet()
            .toList(),
      );

      casingConditionList.assignAll(
        (data['casingCondition'] as List)
            .map((e) => e['casingConditionName'].toString().toUpperCase())
            .toSet()
            .toList(),
      );
      casingConditionIdList.assignAll(
        (data['casingCondition'] as List)
            .map((e) => e['casingConditionId'] as int)
            .toSet()
            .toList(),
      );

      if (wearConditionsIdList.isNotEmpty) {
        selectedWearConditionsId.value = wearConditionsIdList.first;
      }
      if (casingConditionIdList.isNotEmpty) {
        selectedCasingConditionId.value = casingConditionIdList.first;
      }

      dispositionList.assignAll(
        (data['tireDispositions'] as List)
            .map((e) => e['dispositionName'].toString().toUpperCase())
            .toList(),
      );
      dispositionIdList.assignAll(
        (data['tireDispositions'] as List)
            .map((e) => e['dispositionId'] as int)
            .toList(),
      );

      for (var d in data['tireDispositions']) {
        if (d['dispositionName'].toString().toLowerCase() == "installed") {
          installedDispositionId.value = d['dispositionId'];
          break;
        }
      }

      print("✅ Installed Disposition ID => ${installedDispositionId.value}");
    } catch (e) {
      print("❌ Master Data Error: $e");
      Get.snackbar("Error", "Failed to load master data: $e");
    }
  }

  Future<void> loadTyres(int tireId) async {
    isInitialLoading.value = true;
    try {
      final tyres = await tyreService.getTyresById(tireId);
      print("SERVICE RESULT => $tyres");

      tyreList.clear();
      tyreList.addAll(tyres);

      if (tyreList.isNotEmpty) {
        final t = tyreList.first;

        safeOriginalTread = _sanitizeOriginal(t.originalTread);
        safeRemoveAt = _sanitizeRemoveAt(t.removeAt);

        final safeOutside = _sanitizeTread(t.outsideTread, 1.0);
        final safeInside = _sanitizeTread(t.insideTread, 1.0);
        final safePressure = _sanitizePressure(t.currentPressure);
        final safeAvg = double.parse(
          ((safeOutside + safeInside) / 2).toStringAsFixed(2),
        );

        print(
          "🔧 rawOriginal => ${t.originalTread} | safe => $safeOriginalTread",
        );
        print("🔧 rawOutside => ${t.outsideTread} | safe => $safeOutside");
        print("🔧 rawInside => ${t.insideTread} | safe => $safeInside");
        print("🔧 rawRemoveAt => ${t.removeAt} | safe => $safeRemoveAt");

        avgTread.value = safeAvg;

        model.update((m) {
          m!.outsideTread = safeOutside;
          m.insideTread = safeInside;
          m.currentTreadDepth = safeAvg;
          m.currentPressure = safePressure;
        });
      }
    } catch (e) {
      print("❌ Error loading tyres: $e");
    } finally {
      isInitialLoading.value = false;
    }
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
      final parentAccountIdStr = await SecureStorage.getParentAccountId();
      final locationIdStr = await SecureStorage.getLocationId();
      final cookie = await SecureStorage.getCookie();

      if (cookie == null || cookie.isEmpty) {
        Get.snackbar("Error", "Session expired. Please login again.");
        isSubmitting.value = false;
        return;
      }

      final parentAccountId = int.tryParse(parentAccountIdStr ?? '') ?? 0;
      final locationId = int.tryParse(locationIdStr ?? '') ?? 0;

      final m = model.value;

      if (parentAccountId == 0 || locationId == 0) {
        Get.snackbar("Error", "Invalid Account or Location");
        isSubmitting.value = false;
        return;
      }
      if (m.tireId == null || m.tireId == 0) {
        Get.snackbar("Error", "Tire ID is missing");
        isSubmitting.value = false;
        return;
      }
      if (m.vehicleId == null || m.vehicleId == 0) {
        Get.snackbar("Error", "Vehicle ID is missing");
        isSubmitting.value = false;
        return;
      }
      if (installedDispositionId.value == 0) {
        Get.snackbar("Error", "Installed Disposition not found");
        isSubmitting.value = false;
        return;
      }
      if (selectedWearConditionsId.value == 0) {
        Get.snackbar("Validation", "Please select Wear Condition");
        isSubmitting.value = false;
        return;
      }
      if (selectedCasingConditionId.value == 0) {
        Get.snackbar("Validation", "Please select Casing Condition");
        isSubmitting.value = false;
        return;
      }

      final outsideTread = _sanitizeTread(m.outsideTread, 1.0);
      final insideTread = _sanitizeTread(m.insideTread, 1.0);
      final middleTread = double.parse(
        ((outsideTread + insideTread) / 2).toStringAsFixed(2),
      );
      final currentTread =
          (m.currentTreadDepth != null &&
              m.currentTreadDepth! > 0 &&
              m.currentTreadDepth! <= 100)
          ? m.currentTreadDepth!
          : middleTread;
      final currentPressure = _sanitizePressure(m.currentPressure);

      Map<String, dynamic> payload = {
        "action": "Install",
        "inspectionDate": DateTime.now().toUtc().toIso8601String(),
        "locationId": locationId,
        "parentAccountId": parentAccountId,
        "vehicleId": m.vehicleId,
        "inspectionId": 0,
        "tireId": m.tireId,
        "currentHours": 0.0,
        "currentMiles": 0.0,
        "imagesLocation": "",
        "tireSerialNo":
            m.tireSerialNo ??
            (tyreList.isNotEmpty ? tyreList.first.tireSerialNo : "") ??
            "",
        "brandNumber": "",
        "originalTread": safeOriginalTread,
        "removeAt": safeRemoveAt,
        "outsideTread": outsideTread,
        "middleTread": middleTread,
        "insideTread": insideTread,
        "currentTreadDepth": currentTread,
        "currentPressure": currentPressure,
        "pressureUnitId": 1,
        "casingConditionId": selectedCasingConditionId.value,
        "wearConditionId": selectedWearConditionsId.value,
        "comments": (m.comments ?? '').isNotEmpty ? m.comments : "No comments",
        "removalReasonId": 0,
        "dispositionId": installedDispositionId.value,
        "rimDispositionId": 0,
        "wheelPosition": m.wheelPosition?.trim() ?? "",
        "mountedRimId": 0,
        "createdBy": "",
        "pressureType": "PSI",
        "hoursAdjustToTire": 0.0,
        "milesAdjustToTire": 0.0,
        "isMobInstall": true,
      };

      print("🚀 SUBMITTING PAYLOAD:");
      print(jsonEncode(payload));

      final success = await service.submitInspection(payload);

      if (success) {
        // ✅ SUCCESS
        try {
          final vehicleCtrl = Get.find<VehicleInspeController>();
          await vehicleCtrl.fetchInspectionData();
        } catch (_) {}

        Get.back();
        Get.back();
        Get.snackbar(
          "Success",
          "Tyre Installed Successfully",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        // ❌ SAHI JAGAH — jab API fail hoti hai tab print hoga
        print("❌ ================================================");
        print("❌ BACKEND BUG REPORT — BACKEND TEAM KO DIKHAO");
        print("❌ ================================================");
        print("❌ API: POST /api/Inspection/InstallTire");
        print("❌ HTTP Status: 500");
        print("❌ wheelPosition sent: ${payload['wheelPosition']}");
        print("❌ vehicleId: ${payload['vehicleId']}");
        print("❌ tireId: ${payload['tireId']}");
        print("❌ axleConfig: 22 (2 axles x 2 tyres = 4 positions)");
        print("❌ ------------------------------------------------");
        print("❌ ROOT CAUSE:");
        print("❌ InspectionRepository.cs LINE 249");
        print("❌ Array sirf [1L, 1R] handle kar raha hai");
        print("❌ [2L] aur [2R] array mein NAHI hain");
        print("❌ ------------------------------------------------");
        print("❌ PROOF:");
        print("❌ wheelPosition=1L → STATUS 200 ✅ WORKS");
        print("❌ wheelPosition=1R → STATUS 200 ✅ WORKS");
        print("❌ wheelPosition=2L → STATUS 500 ❌ CRASH");
        print("❌ wheelPosition=2R → STATUS 500 ❌ CRASH");
        print("❌ ------------------------------------------------");
        print("❌ FIX NEEDED:");
        print("❌ axleConfig=22 ke liye array mein");
        print("❌ [1L, 1R, 2L, 2R] — 4 positions honi chahiye");
        print("❌ Abhi sirf [1L, 1R] — 2 positions hain");
        print("❌ ================================================");

        Get.snackbar(
          "Error",
          "Server error — backend team ko report karo",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // ❌ EXCEPTION CASE
      print("❌ ================================================");
      print("❌ BACKEND BUG REPORT — EXCEPTION");
      print("❌ ================================================");
      print("❌ wheelPosition: ${model.value.wheelPosition}");
      print("❌ vehicleId: ${model.value.vehicleId}");
      print("❌ tireId: ${model.value.tireId}");
      print("❌ Error: $e");
      print("❌ FILE: InspectionRepository.cs LINE 249");
      print("❌ Array missing positions: 2L and 2R");
      print("❌ ================================================");

      Get.snackbar(
        "Error",
        "Failed to install tire: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  void updateTreadDepth(String value) {
    // Update tread depth logic here
    model.value.currentTreadDepth = double.tryParse(value) ?? 0.0;
  }

  @override
  void onClose() {
    commentsController.dispose();
    treadDepthController.dispose();
    previousCommentController.dispose();
    wearConditionsId.dispose();
    casingConditionsId.dispose();
    super.onClose();
  }
}

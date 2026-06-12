import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

const revenueCatIosApiKey = String.fromEnvironment(
  'REVENUECAT_IOS_API_KEY',
  defaultValue: '',
);

const revenueCatAndroidApiKey = String.fromEnvironment(
  'REVENUECAT_ANDROID_API_KEY',
  defaultValue: '',
);

class RevenueCatService {
  bool _configured = false;
  String? _configuredUserId;

  bool get isConfigured => _configured;

  Future<void> configure(String appUserId) async {
    final key = Platform.isIOS ? revenueCatIosApiKey : revenueCatAndroidApiKey;
    if (key.isEmpty) return;
    if (_configured && _configuredUserId == appUserId) return;
    await Purchases.configure(
      PurchasesConfiguration(key)..appUserID = appUserId,
    );
    _configured = true;
    _configuredUserId = appUserId;
  }

  Future<Offerings?> offerings() async {
    if (!_configured) return null;
    return Purchases.getOfferings();
  }

  Future<void> purchaseDefaultPackage() async {
    final current = (await offerings())?.current;
    final package = current?.availablePackages.isEmpty ?? true
        ? null
        : current!.availablePackages.first;
    if (package == null) {
      throw StateError('No RevenueCat offering is available.');
    }
    await Purchases.purchase(PurchaseParams.package(package));
  }

  Future<void> restorePurchases() async {
    if (!_configured) return;
    await Purchases.restorePurchases();
  }
}

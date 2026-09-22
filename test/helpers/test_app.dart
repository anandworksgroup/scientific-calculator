import 'dart:async';

import 'package:advanced_calculator/app/providers.dart';
import 'package:advanced_calculator/data/database/app_database.dart';
import 'package:advanced_calculator/data/settings/app_settings.dart';
import 'package:advanced_calculator/data/settings/settings_store.dart';
import 'package:advanced_calculator/l10n/generated/app_localizations.dart';
import 'package:advanced_calculator/services/purchase_service.dart';
import 'package:advanced_calculator/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Store backend that never talks to a real store.
class FakePurchaseBackend implements PurchaseBackend {
  FakePurchaseBackend({this.premium = false});
  bool premium;
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<ProductDetails?> product() async => null;
  @override
  Future<void> buy(ProductDetails product) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(PurchaseDetails p) async {}
  @override
  Future<bool> readEntitlement() async => premium;
  @override
  Future<void> writeEntitlement(bool value) async => premium = value;
}

/// Test dependencies: in-memory database, mock preferences, fake store.
class TestDeps {
  TestDeps(this.db, this.store);
  final AppDatabase db;
  final SettingsStore store;

  static Future<TestDeps> create({AppSettings settings = const AppSettings(onboardingDone: true)}) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);
    await store.save(settings);
    final db = await AppDatabase.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    return TestDeps(db, store);
  }

  List overrides() => [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(store),
        purchaseBackendProvider.overrideWithValue(FakePurchaseBackend()),
      ];
}

/// Wraps [child] with theme, localization and providers for widget tests.
Widget testApp(TestDeps deps, Widget child, {Brightness brightness = Brightness.light}) {
  return ProviderScope(
    overrides: [...deps.overrides().cast()],
    child: MaterialApp(
      theme: AppTheme.build(brightness: brightness, accent: 'indigo'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

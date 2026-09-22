import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_logger.dart';

/// Store product for the one-time Premium unlock (non-consumable).
const premiumProductId = 'advanced_calculator_premium';

enum PurchaseIssue { none, unavailable, failed, nothingToRestore }

class PremiumState {
  const PremiumState({
    this.isPremium = false,
    this.pending = false,
    this.loading = false,
    this.storeAvailable = false,
    this.price,
    this.issue = PurchaseIssue.none,
    this.restoredNotice = false,
  });

  final bool isPremium;
  final bool pending;
  final bool loading;
  final bool storeAvailable;

  /// Localized price from the store (e.g. "₹199.00").
  final String? price;
  final PurchaseIssue issue;
  final bool restoredNotice;

  PremiumState copyWith({
    bool? isPremium,
    bool? pending,
    bool? loading,
    bool? storeAvailable,
    String? price,
    PurchaseIssue? issue,
    bool? restoredNotice,
  }) =>
      PremiumState(
        isPremium: isPremium ?? this.isPremium,
        pending: pending ?? this.pending,
        loading: loading ?? this.loading,
        storeAvailable: storeAvailable ?? this.storeAvailable,
        price: price ?? this.price,
        issue: issue ?? this.issue,
        restoredNotice: restoredNotice ?? this.restoredNotice,
      );
}

/// Platform access, replaceable in tests.
abstract class PurchaseBackend {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetails?> product();
  Future<void> buy(ProductDetails product);
  Future<void> restore();
  Future<void> complete(PurchaseDetails p);
  Future<bool> readEntitlement();
  Future<void> writeEntitlement(bool value);
}

class StorePurchaseBackend implements PurchaseBackend {
  final _iap = InAppPurchase.instance;
  static const _storage = FlutterSecureStorage();
  static const _key = 'premium_entitlement_v1';

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetails?> product() async {
    final r = await _iap.queryProductDetails({premiumProductId});
    return r.productDetails.isEmpty ? null : r.productDetails.first;
  }

  @override
  Future<void> buy(ProductDetails product) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(PurchaseDetails p) => _iap.completePurchase(p);

  // The entitlement lives in the Android Keystore / iOS Keychain backed
  // secure storage, not in an editable preferences file, and is
  // re-confirmed with the store whenever it is reachable.
  @override
  Future<bool> readEntitlement() async => (await _storage.read(key: _key)) == premiumProductId;

  @override
  Future<void> writeEntitlement(bool value) =>
      value ? _storage.write(key: _key, value: premiumProductId) : _storage.delete(key: _key);
}

/// Overridable backend (tests use a fake).
final purchaseBackendProvider = Provider<PurchaseBackend>((ref) => StorePurchaseBackend());

class PremiumNotifier extends Notifier<PremiumState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _restoreRequested = false;
  Timer? _restoreTimer;

  PurchaseBackend get _b => ref.read(purchaseBackendProvider);

  @override
  PremiumState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _restoreTimer?.cancel();
    });
    scheduleMicrotask(_init);
    return const PremiumState(loading: true);
  }

  Future<void> _init() async {
    try {
      final cached = await _b.readEntitlement();
      state = state.copyWith(isPremium: cached);
      _sub = _b.purchaseStream.listen(_onPurchases, onError: (Object e) {
        AppLogger.error('purchase stream', e);
        state = state.copyWith(pending: false, issue: PurchaseIssue.failed);
      });
      final available = await _b.isAvailable();
      String? price;
      if (available) {
        final p = await _b.product();
        price = p?.price;
        // Android restores silently; this re-confirms the entitlement.
        if (!kIsWeb && Platform.isAndroid) await _b.restore();
      }
      state = state.copyWith(loading: false, storeAvailable: available, price: price);
    } catch (e) {
      AppLogger.error('purchase init', e);
      state = state.copyWith(loading: false, storeAvailable: false);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != premiumProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(pending: true, issue: PurchaseIssue.none);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _b.writeEntitlement(true);
          state = state.copyWith(
            isPremium: true,
            pending: false,
            issue: PurchaseIssue.none,
            restoredNotice: p.status == PurchaseStatus.restored && _restoreRequested,
          );
          _restoreRequested = false;
        case PurchaseStatus.error:
          state = state.copyWith(pending: false, issue: PurchaseIssue.failed);
        case PurchaseStatus.canceled:
          state = state.copyWith(pending: false);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _b.complete(p);
        } catch (e) {
          AppLogger.error('complete purchase', e);
        }
      }
    }
  }

  Future<void> buy() async {
    state = state.copyWith(issue: PurchaseIssue.none);
    try {
      if (!await _b.isAvailable()) {
        state = state.copyWith(issue: PurchaseIssue.unavailable);
        return;
      }
      final p = await _b.product();
      if (p == null) {
        state = state.copyWith(issue: PurchaseIssue.unavailable);
        return;
      }
      await _b.buy(p);
    } catch (e) {
      AppLogger.error('buy', e);
      state = state.copyWith(issue: PurchaseIssue.failed, pending: false);
    }
  }

  Future<void> restore() async {
    state = state.copyWith(issue: PurchaseIssue.none, restoredNotice: false);
    try {
      if (!await _b.isAvailable()) {
        state = state.copyWith(issue: PurchaseIssue.unavailable);
        return;
      }
      _restoreRequested = true;
      await _b.restore();
      _restoreTimer?.cancel();
      _restoreTimer = Timer(const Duration(seconds: 8), () {
        if (_restoreRequested && !state.isPremium) {
          state = state.copyWith(issue: PurchaseIssue.nothingToRestore);
        }
        _restoreRequested = false;
      });
    } catch (e) {
      AppLogger.error('restore', e);
      state = state.copyWith(issue: PurchaseIssue.failed);
    }
  }

  void clearNotices() => state = state.copyWith(issue: PurchaseIssue.none, restoredNotice: false);
}

final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);

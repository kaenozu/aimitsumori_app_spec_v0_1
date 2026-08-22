/// ファイルパス: lib/services/ad_service.dart
/// AdMob広告と広告削除の非消費型課金を管理するサービス。
library;

import '../utils/app_logger.dart';

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'purchase_verification_retry_store.dart';
import 'purchase_verification_service.dart';

enum RewardedAdOutcome { rewarded, unavailable, dismissed }

class AdService {
  AdService._({PurchaseVerifier? verifier})
    : _verifier = verifier ?? const PurchaseVerificationService();

  @visibleForTesting
  factory AdService.testing({
    bool adFree = true,
    PurchaseVerifier verifier = const TestingPurchaseVerifier(),
  }) {
    final service = AdService._(verifier: verifier);
    service.adFree.value = adFree;
    service._initialized = true;
    return service;
  }

  static final AdService instance = AdService._();

  static const String removeAdsProductId = String.fromEnvironment(
    'REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );
  static const String _adFreePreferenceKey = 'ad_free_verified_cache_v2';
  static const String _adFreeVerifiedAtKey = 'ad_free_verified_at_v2';
  static const Duration _verificationGracePeriod = Duration(days: 7);
  static const Duration _retryRestoreFallback = Duration(minutes: 15);

  static const String _configuredAndroidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: '',
  );
  static const String _configuredIosBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: '',
  );
  static const String _configuredAndroidRewardedId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
    defaultValue: '',
  );
  static const String _configuredIosRewardedId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
    defaultValue: '',
  );

  static const String _androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  final ValueNotifier<bool> adFree = ValueNotifier<bool>(false);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final PurchaseVerifier _verifier;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _removeAdsProduct;
  PurchaseVerificationRetryStore? _verificationRetryStore;
  List<PurchaseVerificationRetryState> _pendingVerificationRetries = const [];
  Timer? _verificationRetryTimer;
  bool _initialized = false;

  bool get isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  String get bannerAdUnitId {
    final configured = defaultTargetPlatform == TargetPlatform.iOS
        ? _configuredIosBannerId
        : _configuredAndroidBannerId;
    final testId = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosTestBannerId
        : _androidTestBannerId;
    return _adUnitId(configured: configured, testId: testId, kind: 'banner');
  }

  String get rewardedAdUnitId {
    final configured = defaultTargetPlatform == TargetPlatform.iOS
        ? _configuredIosRewardedId
        : _configuredAndroidRewardedId;
    final testId = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosTestRewardedId
        : _androidTestRewardedId;
    return _adUnitId(configured: configured, testId: testId, kind: 'rewarded');
  }

  bool get _hasAdConfiguration {
    try {
      return bannerAdUnitId.isNotEmpty && rewardedAdUnitId.isNotEmpty;
    } on StateError {
      return false;
    }
  }

  String _adUnitId({
    required String configured,
    required String testId,
    required String kind,
  }) {
    if (configured.trim().isNotEmpty) return configured.trim();
    if (!kReleaseMode) return testId;
    throw StateError('$kind AdMob unit ID is not configured for release.');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadRecentVerifiedEntitlement();
    await _loadVerificationRetryState();
    if (!isSupportedPlatform) return;

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.debug('Purchase stream error: $error\n$stackTrace');
      },
    );

    if (_hasAdConfiguration) {
      try {
        await MobileAds.instance.initialize();
      } catch (error) {
        AppLogger.debug('Mobile Ads initialization failed: $error');
      }
    }

    try {
      await _loadRemoveAdsProduct();
    } catch (error) {
      AppLogger.debug('Remove ads product load failed: $error');
    }

    // Restoring is also the durable retry transport: after process death the
    // store re-emits a real PurchaseDetails instance, which is then verified
    // against the persisted retry state instead of reconstructing store data.
    await restorePurchases();
    _scheduleVerificationRetry();
  }

  Future<void> _loadRecentVerifiedEntitlement() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cached = preferences.getBool(_adFreePreferenceKey) ?? false;
      final verifiedAtMillis = preferences.getInt(_adFreeVerifiedAtKey);
      if (!cached || verifiedAtMillis == null) return;

      final verifiedAt = DateTime.fromMillisecondsSinceEpoch(verifiedAtMillis);
      final age = DateTime.now().difference(verifiedAt);
      if (!age.isNegative && age <= _verificationGracePeriod) {
        adFree.value = true;
      }
    } catch (error) {
      AppLogger.debug('Ad entitlement cache load failed: $error');
    }
  }

  Future<void> _loadVerificationRetryState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final store = PurchaseVerificationRetryStore(preferences);
      _verificationRetryStore = store;
      await store.prune();
      _pendingVerificationRetries = store.load();
    } catch (error) {
      AppLogger.debug('Purchase verification retry state load failed: $error');
      _pendingVerificationRetries = const [];
    }
  }

  Future<void> _loadRemoveAdsProduct() async {
    if (!await _inAppPurchase.isAvailable()) return;
    final response = await _inAppPurchase.queryProductDetails({
      removeAdsProductId,
    });
    if (response.error != null) {
      AppLogger.debug('Product query failed: ${response.error}');
      return;
    }
    for (final product in response.productDetails) {
      if (product.id == removeAdsProductId) {
        _removeAdsProduct = product;
        return;
      }
    }
  }

  BannerAd? createBannerAd({
    VoidCallback? onLoaded,
    ValueChanged<LoadAdError>? onFailed,
  }) {
    if (!isSupportedPlatform || !_hasAdConfiguration || adFree.value) {
      return null;
    }

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed?.call(error);
        },
      ),
    );
  }

  Future<RewardedAdOutcome> showRewardedAd() async {
    if (adFree.value) return RewardedAdOutcome.rewarded;
    if (!isSupportedPlatform || !_hasAdConfiguration) {
      return RewardedAdOutcome.unavailable;
    }

    final completer = Completer<RewardedAdOutcome>();
    Timer? timeout;
    try {
      timeout = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          completer.complete(RewardedAdOutcome.unavailable);
        }
      });
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            var earnedReward = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (dismissedAd) {
                dismissedAd.dispose();
                if (!completer.isCompleted) {
                  completer.complete(
                    earnedReward
                        ? RewardedAdOutcome.rewarded
                        : RewardedAdOutcome.dismissed,
                  );
                }
              },
              onAdFailedToShowFullScreenContent: (failedAd, error) {
                AppLogger.debug('Rewarded ad failed to show: $error');
                failedAd.dispose();
                if (!completer.isCompleted) {
                  completer.complete(RewardedAdOutcome.unavailable);
                }
              },
            );
            ad.show(onUserEarnedReward: (_, _) => earnedReward = true);
          },
          onAdFailedToLoad: (error) {
            AppLogger.debug('Rewarded ad failed to load: $error');
            if (!completer.isCompleted) {
              completer.complete(RewardedAdOutcome.unavailable);
            }
          },
        ),
      );
    } catch (error) {
      AppLogger.debug('Rewarded ad request failed: $error');
      if (!completer.isCompleted) {
        completer.complete(RewardedAdOutcome.unavailable);
      }
    }
    try {
      return await completer.future;
    } finally {
      timeout?.cancel();
    }
  }

  Future<bool> purchaseRemoveAds() async {
    if (!isSupportedPlatform) return false;
    try {
      _removeAdsProduct ??= await _queryRemoveAdsProduct();
      final product = _removeAdsProduct;
      if (product == null || product.id != removeAdsProductId) return false;
      return _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (error) {
      AppLogger.debug('Remove ads purchase start failed: $error');
      return false;
    }
  }

  Future<ProductDetails?> _queryRemoveAdsProduct() async {
    if (!await _inAppPurchase.isAvailable()) return null;
    final response = await _inAppPurchase.queryProductDetails({
      removeAdsProductId,
    });
    if (response.error != null) return null;
    for (final product in response.productDetails) {
      if (product.id == removeAdsProductId) return product;
    }
    return null;
  }

  Future<void> restorePurchases() async {
    if (!isSupportedPlatform) return;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      AppLogger.debug('Purchase restore failed: $error');
    }
  }

  String _purchaseIdentity(PurchaseDetails purchase) {
    final raw = [
      purchase.productID,
      purchase.purchaseID ?? '',
      purchase.transactionDate ?? '',
      purchase.verificationData.source,
      purchase.verificationData.serverVerificationData,
    ].join('\u001f');
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<PurchaseVerificationRetryState> _recordVerificationRetry(
    PurchaseDetails purchase,
  ) async {
    var store = _verificationRetryStore;
    if (store == null) {
      final preferences = await SharedPreferences.getInstance();
      store = PurchaseVerificationRetryStore(preferences);
      _verificationRetryStore = store;
    }
    final identity = _purchaseIdentity(purchase);
    _pendingVerificationRetries = await store.recordRetry(identity);
    _scheduleVerificationRetry();
    return _pendingVerificationRetries.firstWhere(
      (state) => state.identity == identity,
    );
  }

  Future<void> _clearVerificationRetry(PurchaseDetails purchase) async {
    final store = _verificationRetryStore;
    if (store == null) return;
    _pendingVerificationRetries = await store.remove(_purchaseIdentity(purchase));
    _scheduleVerificationRetry();
  }

  void _scheduleVerificationRetry() {
    _verificationRetryTimer?.cancel();
    _verificationRetryTimer = null;
    if (!isSupportedPlatform || _pendingVerificationRetries.isEmpty) return;

    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final earliest = _pendingVerificationRetries
        .map((state) => state.nextAttemptAtMillis)
        .reduce((left, right) => left < right ? left : right);
    final delayMillis = earliest <= nowMillis ? 0 : earliest - nowMillis;
    _verificationRetryTimer = Timer(
      Duration(milliseconds: delayMillis),
      () => unawaited(_retryPendingPurchases()),
    );
  }

  Future<void> _retryPendingPurchases() async {
    _verificationRetryTimer = null;
    await restorePurchases();
    // Store callbacks normally reschedule using the next persisted backoff.
    // If a store emits nothing, retry later instead of spinning immediately.
    if (_pendingVerificationRetries.isNotEmpty &&
        _verificationRetryTimer == null) {
      _verificationRetryTimer = Timer(
        _retryRestoreFallback,
        () => unawaited(_retryPendingPurchases()),
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsProductId) continue;

      var completePurchase = true;
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final result = await _verifier.verify(purchase);
          switch (result) {
            case PurchaseVerificationResult.valid:
              await _clearVerificationRetry(purchase);
              await _setAdFree(true);
              break;
            case PurchaseVerificationResult.invalid:
              await _clearVerificationRetry(purchase);
              AppLogger.debug('Remove ads purchase verification rejected.');
              await _setAdFree(false);
              break;
            case PurchaseVerificationResult.retryable:
              final retry = await _recordVerificationRetry(purchase);
              completePurchase =
                  PurchaseVerificationRetryPolicy.shouldCompleteStoreTransaction(
                    retry,
                    DateTime.now(),
                  );
              if (completePurchase) {
                AppLogger.debug(
                  'Purchase verification is still retryable after the store '
                  'completion window; completing the store transaction without '
                  'granting a new entitlement and retaining durable retry state.',
                );
              } else {
                AppLogger.debug(
                  'Remove ads purchase verification is retryable; preserving '
                  'the current entitlement and retrying with durable backoff.',
                );
              }
              break;
          }
        } else if (purchase.status == PurchaseStatus.error) {
          await _clearVerificationRetry(purchase);
          AppLogger.debug('Remove ads purchase failed: ${purchase.error}');
        } else if (purchase.status == PurchaseStatus.pending) {
          completePurchase = false;
        }
      } finally {
        if (completePurchase && purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _setAdFree(bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cacheSaved = await preferences.setBool(_adFreePreferenceKey, value);
      final timestampSaved = value
          ? await preferences.setInt(
              _adFreeVerifiedAtKey,
              DateTime.now().millisecondsSinceEpoch,
            )
          : await preferences.remove(_adFreeVerifiedAtKey);
      if (!cacheSaved || !timestampSaved) {
        AppLogger.debug('Ad entitlement cache was not persisted completely.');
      }
    } catch (error) {
      AppLogger.debug('Ad preference save failed: $error');
    }
    adFree.value = value;
  }

  Future<void> dispose() async {
    _verificationRetryTimer?.cancel();
    _verificationRetryTimer = null;
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    adFree.dispose();
  }
}

/// ファイルパス: lib/services/ad_service.dart
/// AdMob広告と広告削除の非消費型課金を管理するサービス。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    if (!kReleaseMode) {
      try {
        final preferences = await SharedPreferences.getInstance();
        adFree.value = preferences.getBool(_adFreePreferenceKey) ?? false;
      } catch (error) {
        debugPrint('Ad preference load failed: $error');
      }
    }
    if (!isSupportedPlatform) return;

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Purchase stream error: $error\n$stackTrace');
      },
    );

    if (_hasAdConfiguration) {
      try {
        await MobileAds.instance.initialize();
      } catch (error) {
        debugPrint('Mobile Ads initialization failed: $error');
      }
    }

    try {
      await _loadRemoveAdsProduct();
    } catch (error) {
      debugPrint('Remove ads product load failed: $error');
    }

    await restorePurchases();
  }

  Future<void> _loadRemoveAdsProduct() async {
    if (!await _inAppPurchase.isAvailable()) return;
    final response = await _inAppPurchase.queryProductDetails({
      removeAdsProductId,
    });
    if (response.error != null) {
      debugPrint('Product query failed: ${response.error}');
      return;
    }
    _removeAdsProduct = response.productDetails
        .where((value) => value.id == removeAdsProductId)
        .firstOrNull;
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
                debugPrint('Rewarded ad failed to show: $error');
                failedAd.dispose();
                if (!completer.isCompleted) {
                  completer.complete(RewardedAdOutcome.unavailable);
                }
              },
            );
            ad.show(
              onUserEarnedReward: (_, _) {
                earnedReward = true;
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
            if (!completer.isCompleted) {
              completer.complete(RewardedAdOutcome.unavailable);
            }
          },
        ),
      );
    } catch (error) {
      debugPrint('Rewarded ad request failed: $error');
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
      debugPrint('Remove ads purchase start failed: $error');
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
      debugPrint('Purchase restore failed: $error');
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
              await _setAdFree(true);
            case PurchaseVerificationResult.invalid:
              debugPrint('Remove ads purchase verification rejected.');
              await _setAdFree(false);
            case PurchaseVerificationResult.retryable:
              completePurchase = false;
              debugPrint(
                'Remove ads purchase verification is retryable; '
                'preserving the current entitlement.',
              );
          }
        } else if (purchase.status == PurchaseStatus.error) {
          debugPrint('Remove ads purchase failed: ${purchase.error}');
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
      final saved = await preferences.setBool(_adFreePreferenceKey, value);
      if (!saved) debugPrint('Ad preference was not persisted.');
    } catch (error) {
      debugPrint('Ad preference save failed: $error');
    }
    adFree.value = value;
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    adFree.dispose();
  }
}

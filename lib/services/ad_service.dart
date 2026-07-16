/// ファイルパス: lib/services/ad_service.dart
/// AdMob広告と広告削除の非消費型課金を管理するサービス
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RewardedAdOutcome {
  rewarded,
  unavailable,
  dismissed,
}

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const String removeAdsProductId = String.fromEnvironment(
    'REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );
  static const String _adFreePreferenceKey = 'ad_free_purchased';

  static const String _androidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String _iosBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const String _androidRewardedId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String _iosRewardedId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  final ValueNotifier<bool> adFree = ValueNotifier<bool>(false);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _removeAdsProduct;
  bool _initialized = false;

  bool get isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  String get bannerAdUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosBannerId
      : _androidBannerId;

  String get rewardedAdUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosRewardedId
      : _androidRewardedId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      adFree.value = preferences.getBool(_adFreePreferenceKey) ?? false;
    } catch (error) {
      debugPrint('Ad preference load failed: $error');
    }
    if (!isSupportedPlatform) return;

    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      debugPrint('Mobile Ads initialization failed: $error');
    }

    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Purchase stream error: $error');
      },
    );

    try {
      await _loadRemoveAdsProduct();
    } catch (error) {
      debugPrint('Remove ads product load failed: $error');
    }
  }

  Future<void> _loadRemoveAdsProduct() async {
    if (!await _inAppPurchase.isAvailable()) return;
    final response =
        await _inAppPurchase.queryProductDetails({removeAdsProductId});
    if (response.error != null) {
      debugPrint('Product query failed: ${response.error}');
      return;
    }
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  BannerAd? createBannerAd({
    VoidCallback? onLoaded,
    ValueChanged<LoadAdError>? onFailed,
  }) {
    if (!isSupportedPlatform || adFree.value) return null;

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
    if (!isSupportedPlatform) return RewardedAdOutcome.unavailable;

    final completer = Completer<RewardedAdOutcome>();
    try {
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
    return completer.future;
  }

  Future<bool> purchaseRemoveAds() async {
    if (!isSupportedPlatform) return false;
    try {
      _removeAdsProduct ??= await _queryRemoveAdsProduct();
      final product = _removeAdsProduct;
      if (product == null) return false;

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
    final response =
        await _inAppPurchase.queryProductDetails({removeAdsProductId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Future<void> restorePurchases() async {
    if (!isSupportedPlatform) return;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      debugPrint('Purchase restore failed: $error');
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _setAdFree(true);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Remove ads purchase failed: ${purchase.error}');
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _setAdFree(bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_adFreePreferenceKey, value);
    } catch (error) {
      debugPrint('Ad preference save failed: $error');
    }
    adFree.value = value;
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    adFree.dispose();
  }
}

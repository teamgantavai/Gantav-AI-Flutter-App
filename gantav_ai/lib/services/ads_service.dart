import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Thin wrapper around `google_mobile_ads` so the rest of the app doesn't
/// import the plugin directly. Centralizes: initialization, unit-ID routing
/// (debug vs release), and the "don't frustrate the user" guardrails.
///
/// ## Placement philosophy
/// The user was explicit: ads must NOT frustrate users. So:
/// - Only banner + medium-rectangle formats (no interstitials, no rewarded
///   popups that block flow).
/// - Inserted inline in scroll lists at a low cadence (every 6–8 cards).
/// - Clearly labeled "Sponsored" so users aren't tricked.
/// - Skipped entirely on web, during video playback, during quizzes, and
///   on celebration screens (certificates, streak bumps, coin earns).
/// - One instance per widget — no preloaded pool on first ship to keep
///   memory footprint low.
class AdsService {
  static bool _initialized = false;

  /// True once [init] has completed successfully. Widgets use this to decide
  /// whether to even attempt loading an ad vs skipping.
  static bool get isReady => _initialized;

  /// Ads are only supported on Android/iOS — not web or desktop. Gate every
  /// ad-loading path on this so web builds don't crash on missing plugin
  /// platform implementations.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Initialize the AdMob SDK. Call once from `main()` after Flutter bindings
  /// are ready. Safe to call multiple times — guarded by [_initialized].
  static Future<void> init() async {
    if (_initialized) return;
    if (!isSupported) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      // Don't let a broken AdMob init kill the whole app — just skip ads
      // for this session. A bad unit ID, missing manifest meta-data, or no
      // network on first launch should all fall through silently.
      debugPrint('[Ads] init failed: $e — ads will be disabled this session');
      _initialized = false;
    }
  }

  /// AdMob unit ID for the medium-rectangle banner we show inside lists.
  ///
  /// Returns Google's official test unit IDs while the app is in debug mode
  /// so developers never accidentally click production ads (which can trip
  /// AdMob fraud detection and suspend the account). Production builds
  /// should return real unit IDs — plug them in below before publish.
  static String get mediumRectangleUnitId {
    if (kDebugMode) {
      // Google-provided test IDs — safe to use, no revenue, no policy risk.
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/6300978111';
      }
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    // TODO(pre-publish): swap these for the real unit IDs from the AdMob
    // console. Leaving test IDs here for now so the first release to the
    // Play Store Internal track doesn't show blank cards.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    return 'ca-app-pub-3940256099942544/2934735716';
  }
}

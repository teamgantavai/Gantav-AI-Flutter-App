import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ads_service.dart';
import '../theme/app_theme.dart';

/// Inline medium-rectangle banner ad styled to match the surrounding course
/// cards so it doesn't feel like a pop-in. Shows a "Sponsored" pill in the
/// top-left corner (Play Store policy: ads must be clearly marked).
///
/// Usage: drop one of these into a ListView or GridView at a low cadence
/// (every 6–8 real items) so ads don't outnumber content. The widget:
/// - Skips itself entirely on web / desktop (ad plugin unsupported)
/// - Returns [SizedBox.shrink] while the ad loads — no reserved blank space
///   that would cause a layout flicker when the ad fills in late
/// - Retries once on load failure, then gives up for the session
class InlineAdCard extends StatefulWidget {
  /// Max width of the ad card. Medium rectangle is 300x250 natively; we
  /// let the surrounding ListView determine the column width and center the
  /// fixed-size ad inside.
  final double maxWidth;
  const InlineAdCard({super.key, this.maxWidth = 360});

  @override
  State<InlineAdCard> createState() => _InlineAdCardState();
}

class _InlineAdCardState extends State<InlineAdCard> {
  BannerAd? _ad;
  bool _failed = false;
  int _retries = 0;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdsService.isSupported || !AdsService.isReady) {
      setState(() => _failed = true);
      return;
    }
    final ad = BannerAd(
      adUnitId: AdsService.mediumRectangleUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[Ads] load failed: ${error.code} ${error.message}');
          if (_retries < 1 && mounted) {
            _retries++;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _loadAd();
            });
          } else if (mounted) {
            setState(() => _failed = true);
          }
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Unsupported platform or failed load — render nothing so the list
    // doesn't have a blank rectangle where an ad was supposed to be.
    if (_failed || kIsWeb) return const SizedBox.shrink();
    final loaded = _ad != null && _ad!.responseInfo != null;
    if (!loaded) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Sponsored" pill — required by Play Store ad policy and good
          // UX regardless. Kept subtle (muted text, small radius) so users
          // don't feel shouted at.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sponsored',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: _ad!.size.width.toDouble(),
              height: _ad!.size.height.toDouble(),
              child: AdWidget(ad: _ad!),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

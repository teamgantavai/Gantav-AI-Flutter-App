import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../services/share_helper.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class ShopBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int cost;

  const ShopBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
  });
}

class BadgeCatalog {
  static const List<ShopBadge> all = [
    ShopBadge(
      id: 'badge_flame',
      title: 'Flame',
      description: 'Show off your burning passion for learning',
      icon: Icons.local_fire_department,
      color: Color(0xFFEF4444),
      cost: 50,
    ),
    ShopBadge(
      id: 'badge_star',
      title: 'All-Star',
      description: 'A star learner recognised by the community',
      icon: Icons.star_rounded,
      color: Color(0xFFF59E0B),
      cost: 75,
    ),
    ShopBadge(
      id: 'badge_rocket',
      title: 'Rocket',
      description: 'Launching into knowledge at full speed',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFF8B5CF6),
      cost: 100,
    ),
    ShopBadge(
      id: 'badge_target',
      title: 'Goal Getter',
      description: 'Never misses a deadline or a lesson',
      icon: Icons.track_changes_rounded,
      color: Color(0xFFF43F5E),
      cost: 120,
    ),
    ShopBadge(
      id: 'badge_brain',
      title: 'Big Brain',
      description: 'Your intellect is undeniable',
      icon: Icons.psychology_rounded,
      color: Color(0xFF10B981),
      cost: 125,
    ),
    ShopBadge(
      id: 'badge_diamond',
      title: 'Diamond',
      description: 'Rare and brilliant — just like your progress',
      icon: Icons.diamond_outlined,
      color: Color(0xFF06B6D4),
      cost: 150,
    ),
    ShopBadge(
      id: 'badge_shield',
      title: 'Steadfast',
      description: 'Unwavering dedication to your learning goals',
      icon: Icons.shield_rounded,
      color: Color(0xFF3B82F6),
      cost: 175,
    ),
    ShopBadge(
      id: 'badge_crown',
      title: 'Crown',
      description: 'Rule the leaderboard with this royal badge',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFF59E0B),
      cost: 200,
    ),
    ShopBadge(
      id: 'badge_medal',
      title: 'Top Scorer',
      description: 'Consistently hitting high marks in quizzes',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFFACC15),
      cost: 250,
    ),
    ShopBadge(
      id: 'badge_fire',
      title: 'Master Flame',
      description: 'The ultimate symbol of intense learning speed',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFEA580C),
      cost: 300,
    ),
    ShopBadge(
      id: 'badge_lightning',
      title: 'Storm Bolt',
      description: 'Lightning fast comprehension and progress',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFDE047),
      cost: 400,
    ),
    ShopBadge(
      id: 'badge_gem',
      title: 'Grand Emerald',
      description: 'The pinnacle of achievement in Gantav AI',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF059669),
      cost: 500,
    ),
  ];
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen>
    with TickerProviderStateMixin {
  // Badge unlock celebration animation
  late AnimationController _celebCtrl;
  late Animation<double> _celebScale;
  late Animation<double> _celebFade;
  ShopBadge? _celebBadge;
  final GlobalKey _celebKey = GlobalKey();

  // Shake animation for insufficient coins
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  String? _shakingBadgeId;

  @override
  void initState() {
    super.initState();

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _celebScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _celebCtrl, curve: Curves.easeOut));
    _celebFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _celebCtrl, curve: const Interval(0.0, 0.4)),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _celebCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase(
      AppState appState, ShopBadge badge, bool isDark) async {
    final coins = appState.user?.coins ?? 0;

    // ── Insufficient coins: shake + snackbar ──────────────────────
    if (coins < badge.cost) {
      HapticFeedback.heavyImpact();
      setState(() => _shakingBadgeId = badge.id);
      await _shakeCtrl.forward(from: 0);
      if (mounted) setState(() => _shakingBadgeId = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not enough coins! You need ${badge.cost - coins} more.',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // ── Confirm dialog ─────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(badge: badge, isDark: isDark),
    );
    if (confirmed != true || !mounted) return;

    final success = await appState.purchaseBadge(badge.id, badge.cost);
    if (!mounted) return;

    if (success) {
      // ── Celebration animation ────────────────────────────────────
      HapticFeedback.mediumImpact();
      setState(() => _celebBadge = badge);
      await _celebCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        _celebCtrl.reverse().then((_) {
          if (mounted) setState(() => _celebBadge = null);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed. Try again.',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppState>(
      builder: (context, appState, _) {
        final coins = appState.user?.coins ?? 0;
        final ownedBadges = appState.ownedBadges;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? AppColors.textLight : AppColors.textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Coin Store',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '$coins coins',
                      style: GoogleFonts.dmMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Banner ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.violet.withValues(alpha: 0.15),
                            AppColors.gold.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.violet.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              color: AppColors.violet, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spend Your Coins',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.textLight
                                        : AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Unlock badges to show on your profile',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Your Badges row ─────────────────────────────────
                  if (ownedBadges.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          'Your Badges',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 84,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: ownedBadges.length,
                          itemBuilder: (ctx, i) {
                            final b = ownedBadges[i];
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 68,
                              decoration: BoxDecoration(
                                color: b.color.withValues(
                                    alpha: isDark ? 0.12 : 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: b.color.withValues(alpha: 0.35),
                                    width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(b.icon, color: b.color, size: 26),
                                  const SizedBox(height: 4),
                                  Text(b.title,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: b.color),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // ── Available Badges grid ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        'Available Badges',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final badge = BadgeCatalog.all[index];
                          final owned = appState.hasBadge(badge.id);
                          final canAfford = coins >= badge.cost;
                          final isShaking = _shakingBadgeId == badge.id;

                          return AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                  isShaking ? _shakeAnim.value : 0, 0),
                              child: child,
                            ),
                            child: _BadgeCard(
                              badge: badge,
                              owned: owned,
                              canAfford: canAfford,
                              coins: coins,
                              isDark: isDark,
                              onBuy: () =>
                                  _handlePurchase(appState, badge, isDark),
                            ),
                          );
                        },
                        childCount: BadgeCatalog.all.length,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Celebration overlay ─────────────────────────────────
              if (_celebBadge != null)
                _BadgeUnlockOverlay(
                  badge: _celebBadge!,
                  scaleAnim: _celebScale,
                  fadeAnim: _celebFade,
                  isDark: isDark,
                  celebKey: _celebKey,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final ShopBadge badge;
  final bool isDark;
  const _ConfirmDialog({required this.badge, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Buy ${badge.title}?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: badge.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: badge.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(badge.icon, color: badge.color, size: 34),
          ),
          const SizedBox(height: 12),
          Text(badge.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text('${badge.cost} coins',
                    style: GoogleFonts.dmMono(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.gold)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.dmSans(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Buy',
              style:
                  GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Badge unlock celebration overlay ────────────────────────────────────────

class _BadgeUnlockOverlay extends StatelessWidget {
  final ShopBadge badge;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final bool isDark;
  final GlobalKey celebKey;

  const _BadgeUnlockOverlay({
    required this.badge,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.isDark,
    required this.celebKey,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: AnimatedBuilder(
            animation: scaleAnim,
            builder: (_, __) => FadeTransition(
              opacity: fadeAnim,
              child: Transform.scale(
                scale: scaleAnim.value,
                child: RepaintBoundary(
                  key: celebKey,
                  child: Container(
                    width: 300,
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 28),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: badge.color.withValues(alpha: 0.4),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: badge.color.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: badge.color.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(badge.icon,
                              color: badge.color, size: 40),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '🎉 Badge Unlocked!',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: badge.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: badge.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: badge.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Now showing on your profile ✨',
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badge.color),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ShareHelper.shareWidgetAsImage(
                                key: celebKey,
                                text: 'I just unlocked the ${badge.title} badge on Gantav AI! 🎯\n\n${badge.description}',
                                fileName: 'gantav_badge_${badge.id}',
                              );
                            },
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: Text('Share Achievement',
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: badge.color,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Badge Card ───────────────────────────────────────────────────────────────

class _BadgeCard extends StatefulWidget {
  final ShopBadge badge;
  final bool owned;
  final bool canAfford;
  final int coins;
  final bool isDark;
  final VoidCallback onBuy;

  const _BadgeCard({
    required this.badge,
    required this.owned,
    required this.canAfford,
    required this.coins,
    required this.isDark,
    required this.onBuy,
  });

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final owned = widget.owned;
    final canAfford = widget.canAfford;
    final coins = widget.coins;
    final isDark = widget.isDark;
    final onBuy = widget.onBuy;

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: owned
            ? badge.color.withValues(alpha: isDark ? 0.13 : 0.08)
            : isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: owned
              ? badge.color.withValues(alpha: 0.45)
              : !canAfford
                  ? (isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder)
                  : badge.color.withValues(alpha: 0.2),
          width: owned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badge.color.withValues(
                      alpha: owned ? 0.18 : canAfford ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(badge.icon,
                    color: badge.color.withValues(
                        alpha: owned
                            ? 1.0
                            : canAfford
                                ? 1.0
                                : 0.45),
                    size: 26),
              ),
              if (owned)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Owned',
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badge.color),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            badge.title,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: owned || canAfford
                  ? (isDark ? AppColors.textLight : AppColors.textDark)
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (owned)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: badge.color, size: 14),
                const SizedBox(width: 4),
                Text('Unlocked',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badge.color)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ShareHelper.shareWidgetAsImage(
                      key: _cardKey,
                      text: 'I just unlocked the ${badge.title} badge on Gantav AI! 🎯\n\n${badge.description}',
                      fileName: 'gantav_badge_${badge.id}',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.share_rounded,
                        color: badge.color, size: 14),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                // Always tappable — blocking & feedback handled in _handlePurchase
                onPressed: onBuy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford
                      ? AppColors.violet
                      : AppColors.error.withValues(alpha: 0.12),
                  foregroundColor:
                      canAfford ? Colors.white : AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      canAfford
                          ? Icons.monetization_on_rounded
                          : Icons.lock_outline_rounded,
                      size: 13,
                      color: canAfford ? AppColors.gold : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      // Show how many more coins are needed when can't afford
                      canAfford
                          ? '${badge.cost}'
                          : 'Need ${badge.cost - coins} more',
                      style: GoogleFonts.dmMono(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
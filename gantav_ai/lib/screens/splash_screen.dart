import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _taglineFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _taglineFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF0F071A), const Color(0xFF050208)]
              : [const Color(0xFFF9F7FF), const Color(0xFFEBE5FF)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.violet.withValues(alpha: isDark ? 0.3 : 0.15),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                                spreadRadius: -10,
                              )
                            ],
                          ),
                          child: Image.asset('assets/images/logo.png'),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Gantav AI',
                    style: GoogleFonts.dmSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tagline
                FadeTransition(
                  opacity: _taglineFadeAnimation,
                  child: Text(
                    'गंतव्य · Your Destination',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violet.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            // Bottom "Activity" indicator
            Positioned(
              bottom: 60,
              child: FadeTransition(
                opacity: _taglineFadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.violet),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI is curating your world',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
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

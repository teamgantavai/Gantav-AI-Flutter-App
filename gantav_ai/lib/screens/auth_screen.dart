import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';

/// Auth screen — handles onboarding flow:
/// 1. Dream input (first screen, no sign-in required)
/// 2. When "Generate" is tapped → sign-in gate appears
/// 3. After sign-in → AI generates course → main app
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePass = true;
  String? _error;
  String? _emailError;
  String? _passError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _validateFields() {
    bool valid = true;
    setState(() {
      _emailError = AuthService.validateEmail(_emailCtrl.text.trim());
      _passError = AuthService.validatePassword(_passCtrl.text.trim());
      if (_isSignUp) {
        _nameError = AuthService.validateName(_nameCtrl.text.trim());
      } else {
        _nameError = null;
      }
      if (_emailError != null || _passError != null || _nameError != null) {
        valid = false;
      }
    });
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: _buildAuthPage(isDark),
      ),
    );
  }

  Future<void> _authenticate() async {
    if (!_validateFields()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    setState(() { _loading = true; _error = null; });

    if (!mounted) return;

    final appState = context.read<AppState>();
    bool success;

    if (_isSignUp) {
      success = await appState.signUpWithEmail(
        email: email,
        password: pass,
        name: name,
      );
    } else {
      success = await appState.signInWithEmail(
        email: email,
        password: pass,
      );
    }

    if (!mounted) return;

    if (!success) {
      setState(() {
        _error = appState.authError;
        _loading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = null; });

    final appState = context.read<AppState>();
    final success = await appState.signInWithGoogle();

    if (!mounted) return;

    if (!success) {
      setState(() {
        _error = appState.authError;
        _googleLoading = false;
      });
    }
  }


  Widget _buildAuthPage(bool isDark) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),

            // Logo + wordmark
            Center(
              child: Column(
                children: [
                  const _GantavLogo(size: 64),
                  const SizedBox(height: 16),
                  Text('Gantav AI',
                    style: GoogleFonts.dmSans(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    )),
                  Text('गंतव्य · Your Destination',
                    style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textMuted,
                    )),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Headline
            Text(_isSignUp ? 'Create your account' : 'Welcome back',
              style: GoogleFonts.dmSans(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark,
                letterSpacing: -0.5,
              )),
            const SizedBox(height: 6),
            Text(_isSignUp
                ? 'Sign up to start your learning journey'
                : 'Sign in to access your personalised courses',
              style: GoogleFonts.dmSans(
                fontSize: 14, height: 1.5,
                color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
              )),

            const SizedBox(height: 32),

            // ─── Google Sign-In Button ───────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _googleLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textLight : AppColors.textDark,
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                child: _googleLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google "G" logo
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Image.asset('assets/images/google.png'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
                ),
                Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              ],
            ),

            const SizedBox(height: 20),

            // Form
            if (_isSignUp) ...[
              _FieldLabel('Your name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _nameError = null),
                style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Rahul Sharma',
                  prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.textMuted),
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 16),
            ],

            _FieldLabel('Email address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _emailError = null),
              style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.textMuted),
                errorText: _emailError,
              ),
            ),

            const SizedBox(height: 16),

            _FieldLabel('Password'),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              onChanged: (_) => setState(() => _passError = null),
              style: GoogleFonts.dmSans(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textMuted),
                errorText: _passError,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  icon: Icon(
                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20, color: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            // Password strength indicator for sign-up
            if (_isSignUp && _passCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PasswordStrength(password: _passCtrl.text),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Sign in / Sign up button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  disabledBackgroundColor: AppColors.violet.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isSignUp ? Icons.person_add_rounded : Icons.login_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Toggle sign in / sign up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp ? 'Already have an account? ' : 'New to Gantav AI? ',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() { _isSignUp = !_isSignUp; _error = null; _emailError = null; _passError = null; _nameError = null; }),
                  child: Text(
                    _isSignUp ? 'Sign in' : 'Create account',
                    style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Skip for now
            Center(
              child: GestureDetector(
                onTap: () async {
                  final appState = context.read<AppState>();
                  await appState.skipAuth();
                },
                child: Text(
                  'Skip for now →',
                  style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  @override
  Widget build(BuildContext context) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    final colors = [AppColors.error, AppColors.error, AppColors.warning, AppColors.gold, AppColors.success, AppColors.success];
    final labels = ['Very weak', 'Weak', 'Fair', 'Good', 'Strong', 'Very strong'];

    return Row(
      children: [
        ...List.generate(5, (i) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i <= strength ? colors[strength] : colors[strength].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        )),
        const SizedBox(width: 8),
        Text(labels[strength],
          style: GoogleFonts.dmSans(fontSize: 11, color: colors[strength], fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(text,
      style: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textLightSub : AppColors.textDarkSub,
        letterSpacing: 0.2,
      ));
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TrustBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(height: 4),
        Text(text,
          style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _GantavLogo extends StatelessWidget {
  final double size;
  const _GantavLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}



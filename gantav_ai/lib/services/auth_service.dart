import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Authentication result wrapper
class AuthResult {
  final User? user;
  final String? error;
  final bool isNewUser;

  AuthResult({this.user, this.error, this.isNewUser = false});

  bool get success => user != null && error == null;
}

/// Firebase Auth wrapper with Google Sign-In
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '88076839712-2i6p18rnb1bgs2u7b69cvb8m5lp3ck6l.apps.googleusercontent.com' : null,
  );

  /// Current user
  static User? get currentUser => _auth.currentUser;

  /// Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(error: 'Google sign-in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;

      return AuthResult(
        user: userCredential.user,
        isNewUser: isNew,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return AuthResult(error: 'Failed to sign in with Google. Please try again.');
    }
  }

  /// Sign up with email and password
  static Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      return AuthResult(
        user: _auth.currentUser,
        isNewUser: true,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('Sign-up error: $e');
      return AuthResult(error: 'Failed to create account. Please try again.');
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return AuthResult(user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('Sign-in error: $e');
      return AuthResult(error: 'Failed to sign in. Please try again.');
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  /// Send a Firebase password-reset email. Returns null on success, or a
  /// user-facing error string on failure. Used by the "Forgot password?"
  /// flow on the auth screen.
  static Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    } catch (e) {
      debugPrint('Password reset error: $e');
      return 'Failed to send reset email. Please try again.';
    }
  }

  /// Send email verification
  static Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return AuthResult(user: user);
      }
      return AuthResult(error: 'No user signed in');
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('Email verification error: $e');
      return AuthResult(error: 'Failed to send verification email.');
    }
  }

  /// List of developer/admin emails who have access to the hidden admin panel
  static const List<String> _authorizedEmails = [
    'teamgantavai@gmail.com',
    'official.diljha@gmail.com',
    // Add more emails here as provided by the user
  ];

  /// Check if the currently signed-in user has admin/developer access
  static bool get isAdmin {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    return _authorizedEmails.contains(user.email);
  }

  /// Map Firebase error codes to user-friendly messages
  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found with this email. Create one instead.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again to perform this action.';
      case 'channel-error':
        return 'Please fill in all fields.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  /// Validate email format
  static String? validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(email)) return 'Please enter a valid email';
    return null;
  }

  /// Validate password
  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Validate name
  static String? validateName(String name) {
    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }
}

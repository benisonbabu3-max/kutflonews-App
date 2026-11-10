import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ════════════════════════════════════════════════════════════════════════
/// SupabaseService — single entry point for auth + backend calls.
///
/// SETUP:
/// 1. Create a free project at https://supabase.com
/// 2. Run supabase/migrations/001_init.sql in the SQL editor
/// 3. Deploy edge functions: supabase functions deploy enrich-article
///    ai-chat generate-briefs
/// 4. Set secrets: supabase secrets set NVIDIA_NIM_API_KEY=nvapi-xxxx
/// 5. Enable Google provider in Authentication → Providers
/// 6. Fill in the constants below
/// ════════════════════════════════════════════════════════════════════════
class SupabaseConfig {
  // TODO: replace with your project values (Project Settings → API)
  static const String url = 'https://YOUR_PROJECT.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY';

  // TODO: from Google Cloud Console → OAuth client (Web application type)
  // Used by google_sign_in on Android/iOS for the native sign-in flow.
  static const String googleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
}

class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  late final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: SupabaseConfig.googleWebClientId,
    );
    _initialized = true;
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;
  bool get isSignedIn => currentSession != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Native Google sign-in → exchange ID token with Supabase Auth.
  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // ensure account picker shows
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign-in cancelled');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('No ID token returned by Google');

      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (kDebugMode) print('Google sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    await client.auth.signOut();
  }

  // ── Edge function calls ──────────────────────────────────────────────

  /// Calls an edge function and returns the decoded JSON body.
  /// Throws on network error or non-2xx response.
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final res = await client.functions.invoke(
      functionName,
      body: body,
    );
    if (res.status != 200) {
      throw Exception('$functionName failed (${res.status}): ${res.data}');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }
}

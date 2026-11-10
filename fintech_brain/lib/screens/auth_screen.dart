import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/theme.dart';

/// Sign-in gate — shown when no Supabase session exists.
/// Single button: "Continue with Google" (native sign-in via google_sign_in
/// + Supabase Auth token exchange).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _supa = SupabaseService.instance;
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _supa.signInWithGoogle();
      // Auth state listener in main.dart handles navigation.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Spacer(flex: 3),
            // Logo mark
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.nearBlack, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text('FB',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: Colors.white, fontFamily: 'Inter')),
            ),
            const SizedBox(height: 24),
            const Text('Fintech Brain',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -.5, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text('Become smarter in the room.\n10 minutes a day, every day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: AppColors.textSecondary, height: 1.5, fontFamily: 'Inter')),
            const Spacer(flex: 4),
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE9E7),
                  border: Border.all(color: AppColors.accentDark.withOpacity(.3), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.accentDark, fontFamily: 'Inter')),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _loading ? null : _signIn,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.nearBlack,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _loading
                    ? const Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.base)))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 20, height: 20,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                          alignment: Alignment.center,
                          child: const Text('G', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                            color: AppColors.accent, fontFamily: 'Inter'))),
                        const SizedBox(width: 10),
                        const Text('Continue with Google',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: AppColors.base, fontFamily: 'Inter')),
                      ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Your data stays private. AI summaries are shared\nanonymously to keep this app free.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: AppColors.textMuted, height: 1.5, fontFamily: 'Inter')),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

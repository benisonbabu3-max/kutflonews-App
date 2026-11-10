import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/article.dart';
import 'services/article_repository.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/vault_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive (local cache + offline support)
  await Hive.initFlutter();
  Hive.registerAdapter(ArticleAdapter());
  Hive.registerAdapter(ArticleTypeAdapter());
  await ArticleRepository.instance.init();

  // Supabase (auth + shared AI cache backend)
  try {
    await SupabaseService.instance.init();
  } catch (_) {}

  // Notifications
  try {
    await NotificationService.init();
    final profile = await ArticleRepository.instance.getProfile();
    await NotificationService.scheduleDailyReminders(
      morningHour: profile.morningHour, eveningHour: profile.eveningHour);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const FintechBrainApp());
}


class FintechBrainApp extends StatelessWidget {
  const FintechBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fintech Brain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
      routes: {
        '/profile':  (_) => const ProfileScreen(),
        '/feed':     (_) => const FeedScreen(),
        '/vault':    (_) => const VaultScreen(),
        '/progress': (_) => const ProgressScreen(),
      },
    );
  }
}

/// Shows AuthScreen until signed in, then MainShell.
/// Listens to Supabase auth state so sign-in/out reroutes automatically.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supa = SupabaseService.instance;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _signedIn = _supa.isSignedIn;
    _supa.authStateChanges.listen((state) {
      final signedIn = state.session != null;
      if (signedIn != _signedIn && mounted) {
        setState(() => _signedIn = signedIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _signedIn ? const MainShell() : const AuthScreen();
  }
}


class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    FeedScreen(),
    VaultScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.base,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(icon: _NavIcon.home,     label: 'Home',     idx: 0, cur: _tab, onTap: _setTab),
              _NavItem(icon: _NavIcon.feed,     label: 'Feed',     idx: 1, cur: _tab, onTap: _setTab),
              _NavItem(icon: _NavIcon.vault,    label: 'Vault',    idx: 2, cur: _tab, onTap: _setTab),
              _NavItem(icon: _NavIcon.progress, label: 'Progress', idx: 3, cur: _tab, onTap: _setTab),
              _NavItem(icon: _NavIcon.profile,  label: 'Profile',  idx: 4, cur: _tab, onTap: _setTab),
            ],
          ),
        ),
      ),
    );
  }

  void _setTab(int idx) {
    if (idx == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return;
    }
    setState(() => _tab = idx);
  }
}

enum _NavIcon { home, feed, vault, progress, profile }

class _NavItem extends StatelessWidget {
  final _NavIcon icon;
  final String label;
  final int idx, cur;
  final void Function(int) onTap;

  const _NavItem({required this.icon, required this.label,
    required this.idx, required this.cur, required this.onTap});

  bool get _selected => idx == cur;

  @override
  Widget build(BuildContext context) {
    final color = _selected ? AppColors.nearBlack : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildIcon(color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Inter', letterSpacing: .03)),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _selected ? 16 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    switch (icon) {
      case _NavIcon.home:
        return Icon(Icons.home_outlined, size: 22, color: color);
      case _NavIcon.feed:
        return Icon(Icons.article_outlined, size: 22, color: color);
      case _NavIcon.vault:
        return Icon(Icons.lightbulb_outline_rounded, size: 22, color: color);
      case _NavIcon.progress:
        return Icon(Icons.bar_chart_rounded, size: 22, color: color);
      case _NavIcon.profile:
        return Icon(Icons.person_outline_rounded, size: 22, color: color);
    }
  }
}

// Note: google_fonts package fetches Inter from Google CDN on first run
// and caches locally. Requires internet on first launch.

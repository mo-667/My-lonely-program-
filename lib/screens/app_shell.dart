part of '../main.dart';

class ShadowChatApp extends StatelessWidget {
  const ShadowChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: englishLanguageNotifier,
      builder: (context, isEnglish, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: globalDarkModeNotifier,
          builder: (context, isDark, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.light(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: const Color(0xFFF4F7F6),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF167A5A),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFEAF1EF),
                  foregroundColor: Color(0xFF14211D),
                ),
                cardTheme: const CardThemeData(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                ),
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: Color(0xFFF1F5F3),
                ),
              ),
              darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: const Color(0xFF101716),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF38E8A5),
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF15211F),
                  foregroundColor: Color(0xFFE8F3EF),
                ),
                cardTheme: const CardThemeData(
                  color: Color(0xFF192522),
                  surfaceTintColor: Colors.transparent,
                ),
                dividerTheme: const DividerThemeData(color: Color(0x334DD6A2)),
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: Color(0xFF1C2B27),
                ),
              ),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: Directionality(
                textDirection: isEnglish
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: const StartupGate(),
              ),
            );
          },
        );
      },
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  static const String _introSeenKey = 'startup_intro_seen';

  @override
  void initState() {
    super.initState();
    _showStartupInfoIfNeeded();
  }

  Future<void> _showStartupInfoIfNeeded() async {
    final preferences = await getSafeSharedPreferences();
    if (preferences == null || !mounted) return;
    if (preferences.getBool(_introSeenKey) == true || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF38E8A5)),
            SizedBox(width: 10),
            Text('Shadow Chat BETA'),
          ],
        ),
        content: const Text(
          'مساحتك الخاصة للمحادثات. يستخدم التطبيق Firebase لحفظ الرسائل، ويطلب الإشعارات لإبلاغك بالرسائل الجديدة، والكاميرا والميكروفون عند استخدام الوسائط أو الرسائل الصوتية.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
    await preferences.setBool(_introSeenKey, true);
  }

  @override
  Widget build(BuildContext context) => const AuthGate();
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isTryingAnonymousLogin = false;
  bool _sessionPrepared = false;
  bool _preparingSession = false;
  String? _authError;

  Future<void> _ensureAnonymousLogin() async {
    if (!firebaseReady || FirebaseAuth.instance.currentUser != null) return;

    try {
      await FirebaseAuth.instance.signInAnonymously();
      await ensureUserProfile();
      await loadRoomOwnerKey();
      await loadSecretRoomCode();
      await setupPushNotifications();
      if (mounted) setState(() => _authError = null);
    } catch (error) {
      debugPrint('Anonymous login failed: $error');
      if (mounted) {
        setState(() {
          _isTryingAnonymousLogin = false;
          _authError = error.toString();
        });
      }
    }
  }

  Future<void> _prepareAuthenticatedSession() async {
    if (_sessionPrepared || _preparingSession) return;
    _preparingSession = true;
    try {
      await ensureUserProfile();
      await setupPushNotifications();
      await loadAppLockSettings();
      await loadSecretGroupSettings();
      if (mounted) setState(() => _authError = null);
    } catch (error) {
      debugPrint('Authenticated session setup failed: $error');
      if (mounted) {
        setState(() => _authError = error.toString());
      }
    } finally {
      _sessionPrepared = true;
      _preparingSession = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (secureLocalDemoMode) {
      return const AppLockGate();
    }

    if (!firebaseReady) {
      return Scaffold(
        body: Center(
          child: Text(
            'الوضع المحلي مفعل\nسيتم استكمال المزايا عند اتصال Firebase',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == null) {
          if (!_isTryingAnonymousLogin) {
            _isTryingAnonymousLogin = true;
            unawaited(_ensureAnonymousLogin());
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    _authError == null
                        ? 'جاري تجهيز التطبيق...'
                        : 'حدثت مشكلة، حاول مرة أخرى',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_authError != null)
                    TextButton.icon(
                      onPressed: _ensureAnonymousLogin,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                ],
              ),
            ),
          );
        }

        if (!_sessionPrepared) {
          unawaited(_prepareAuthenticatedSession());
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const AppLockGate();
      },
    );
  }
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _passwordController = TextEditingController();
  late AnimationController _lockAnimationController;
  late Animation<double> _lockAnimation;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(updatePresence(true));
    appLockEnabledNotifier.addListener(_onLockChanged);
    _unlocked = !appLockEnabledNotifier.value;
    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _lockAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _lockAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(updatePresence(true));
      if (firebaseReady && FirebaseAuth.instance.currentUser != null) {
        unawaited(loadPrivacySettings());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(updatePresence(false));
    }
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        appLockEnabledNotifier.value &&
        mounted) {
      setState(() => _unlocked = false);
    }
  }

  void _onLockChanged() {
    if (!appLockEnabledNotifier.value) {
      setState(() => _unlocked = true);
    } else if (appLockPasswordNotifier.value != null) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _unlock() async {
    if (await hashPassword(_passwordController.text.trim()) ==
        appLockPasswordNotifier.value) {
      setState(() {
        _unlocked = true;
        _passwordController.clear();
      });
    } else {
      debugPrint('App lock password check failed');
    }
  }

  @override
  void dispose() {
    unawaited(updatePresence(false));
    WidgetsBinding.instance.removeObserver(this);
    appLockEnabledNotifier.removeListener(_onLockChanged);
    _lockAnimationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked || !appLockEnabledNotifier.value)
      return const ChatListScreen();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: const Color(0xFF06110D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF071A13), Color(0xFF020504)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  '✦  SHADOW SHAT  ✦',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const Text(
                'Private space',
                style: TextStyle(
                  color: Color(0xFF8BA99A),
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 410),
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1B15).withOpacity(0.96),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFF3D8062).withOpacity(0.45),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3300FF66),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: _lockAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(19),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00FF66).withOpacity(0.1),
                                border: Border.all(
                                  color: const Color(0xFF00FF66),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.phonelink_lock_rounded,
                                color: Color(0xFF00FF66),
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'APP SECURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'مساحتك الخاصة محمية بالكامل',
                            style: TextStyle(
                              color: Color(0xFF9BB5A7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 25),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                            decoration: InputDecoration(
                              hintText: 'اكتب كلمة مرورك هنا',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                letterSpacing: 0,
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.28),
                              prefixIcon: const Icon(
                                Icons.key_rounded,
                                color: Colors.amberAccent,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00FF66),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _unlock(),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _unlock,
                              icon: const Icon(Icons.lock_open_rounded),
                              label: const Text(
                                'دخول آمن',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF66),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          if (appLockEnabledNotifier.value)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed: () =>
                                    showChangeAppLockPasswordDialog(context),
                                icon: const Icon(
                                  Icons.password_rounded,
                                  size: 18,
                                ),
                                label: const Text('تغيير كلمة سر قفل التطبيق'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 15),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: Colors.amberAccent,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Shadow Chat Security',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 1. القائمة الرئيسية

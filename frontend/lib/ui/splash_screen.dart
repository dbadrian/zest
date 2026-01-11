import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zest/authentication/auth_service.dart';
import 'package:zest/recipes/screens/recipe_search.dart';
import 'package:zest/settings/settings_provider.dart';
import 'package:zest/ui/login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  static String get routeName => 'splash';
  static String get routeLocation => '/$routeName';

  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade-in animation
    _animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 2));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate loading data
    await Future.delayed(Duration(seconds: 2));

    // Perform network test
    bool isAuthed = await _refreshAuthState();
    if (isAuthed) {
      if (mounted) {
        context.goNamed(RecipeSearchPage.routeName);
      }
    } else {
      if (mounted) {
        context.goNamed(LoginPage.routeName);
      }
    }
  }

  Future<bool> _refreshAuthState() async {
    try {
      return await ref
          .read(authenticationServiceProvider.notifier)
          .refreshToken();
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final settings = ref.read(settingsProvider).current;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // colors: [settings.themeBaseColor, Colors.orange.shade400],
                colors: [
                  Color.lerp(settings.themeBaseColor, Colors.white, 0.2)!,
                  Color.lerp(settings.themeBaseColor, Colors.black, 0.2)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Centered content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App logo placeholder (replace with your asset if you have one)
                  Container(
                    width: size.width * 0.3,
                    height: size.width * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Text(
                        "Z",
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // App name / tagline
                  Text(
                    "Loading Zest...",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black26,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Progress indicator
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),

                  SizedBox(height: 8),

                  Text(
                    "Please be patient",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

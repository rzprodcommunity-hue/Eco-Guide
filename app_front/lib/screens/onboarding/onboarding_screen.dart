import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      gradient: [Color(0xFF0E7A23), Color(0xFF1AAF3C)],
      icon: Icons.landscape_rounded,
      title: 'Bienvenue sur Eco-Guide',
      subtitle:
          'Votre compagnon intelligent pour explorer la nature algérienne en toute sécurité.',
      imagePath: 'assets/images/logo.png',
      isLogo: true,
    ),
    _OnboardingPage(
      gradient: [Color(0xFF1565C0), Color(0xFF0288D1)],
      icon: Icons.map_rounded,
      title: 'Carte Interactive',
      subtitle:
          'Explorez les sentiers et points d\'intérêt sur une carte détaillée. Fonctionne même hors connexion.',
      imagePath: null,
      isLogo: false,
    ),
    _OnboardingPage(
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      icon: Icons.hiking_rounded,
      title: 'Sentiers & POIs',
      subtitle:
          'Découvrez des sentiers classés par difficulté et des points d\'intérêt naturels et culturels.',
      imagePath: null,
      isLogo: false,
    ),
    _OnboardingPage(
      gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
      icon: Icons.quiz_rounded,
      title: 'Quiz Nature',
      subtitle:
          'Testez vos connaissances sur la faune, la flore et l\'écologie. Gagnez des badges et grimpez au classement.',
      imagePath: null,
      isLogo: false,
    ),
    _OnboardingPage(
      gradient: [Color(0xFFC62828), Color(0xFFE53935)],
      icon: Icons.sos_rounded,
      title: 'SOS & Sécurité',
      subtitle:
          'Envoyez une alerte d\'urgence géolocalisée en un seul geste, même sans connexion internet.',
      imagePath: null,
      isLogo: false,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, animation, secondary) => const AppWrapper(),
        transitionsBuilder: (ctx, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: page.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                ),
              ),

              // Dots + button
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                child: Row(
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _currentPage ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Next / Start button
                    GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? 'Commencer' : 'Suivant',
                              style: TextStyle(
                                color: page.gradient.first,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLast
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              color: page.gradient.first,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imagePath;
  final bool isLogo;

  const _OnboardingPage({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.isLogo,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;

  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: page.isLogo && page.imagePath != null
                ? Padding(
                    padding: const EdgeInsets.all(36),
                    child: Image.asset(
                      page.imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        page.icon,
                        size: 90,
                        color: Colors.white,
                      ),
                    ),
                  )
                : _FeatureIllustration(page: page),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  final _OnboardingPage page;

  const _FeatureIllustration({required this.page});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer decorative ring
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
        ),
        // Inner icon circle
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(page.icon, size: 52, color: Colors.white),
        ),
      ],
    );
  }
}

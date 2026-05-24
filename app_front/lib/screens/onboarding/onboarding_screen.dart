import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

class OnboardingScreen extends StatefulWidget {
  /// When [isReplay] is true the tutorial was opened again from inside the app
  /// (e.g. the Help Center). In that mode finishing/skipping simply pops back
  /// instead of marking onboarding as done and rebuilding the app.
  final bool isReplay;

  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _floatCtrl;
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
      highlights: [
        'Sentiers, POIs et services locaux réunis',
        'Fonctionne aussi sans connexion internet',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFF1565C0), Color(0xFF0288D1)],
      icon: Icons.map_rounded,
      title: 'Carte Interactive',
      subtitle:
          'Explorez les sentiers et points d\'intérêt sur une carte détaillée. Fonctionne même hors connexion.',
      imagePath: null,
      isLogo: false,
      highlights: [
        'Plusieurs styles : standard, relief, satellite',
        'Itinéraires et navigation GPS',
        'Mode hors-ligne téléchargeable',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      icon: Icons.hiking_rounded,
      title: 'Sentiers & POIs',
      subtitle:
          'Découvrez des sentiers classés par difficulté et des points d\'intérêt naturels et culturels.',
      imagePath: null,
      isLogo: false,
      highlights: [
        'Difficulté, distance, durée et dénivelé',
        'Guide audio (voice-over) pour les POIs',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
      icon: Icons.quiz_rounded,
      title: 'Quiz Nature',
      subtitle:
          'Testez vos connaissances sur la faune, la flore et l\'écologie. Gagnez des badges et grimpez au classement.',
      imagePath: null,
      isLogo: false,
      highlights: [
        'Catégories faune, flore et écologie',
        'Gagnez des badges et suivez vos scores',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFFC62828), Color(0xFFE53935)],
      icon: Icons.sos_rounded,
      title: 'SOS & Sécurité',
      subtitle:
          'Envoyez une alerte d\'urgence géolocalisée en un seul geste, même sans connexion internet.',
      imagePath: null,
      isLogo: false,
      highlights: [
        'Alerte géolocalisée en un geste',
        'File d\'attente hors-ligne automatique',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  Future<void> _finish() async {
    if (widget.isReplay) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
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

  void _previous() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;
    final isFirst = _currentPage == 0;

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
              // Top bar: step counter + Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_pages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        widget.isReplay ? 'Fermer' : 'Passer',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) =>
                      _PageContent(page: _pages[i], float: _floatCtrl),
                ),
              ),

              // Dots + navigation buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Row(
                  children: [
                    // Back button (hidden on first page)
                    AnimatedOpacity(
                      opacity: isFirst ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: isFirst,
                        child: GestureDetector(
                          onTap: _previous,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              isLast
                                  ? (widget.isReplay ? 'Terminé' : 'Commencer')
                                  : 'Suivant',
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
  final List<String> highlights;

  const _OnboardingPage({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.isLogo,
    this.highlights = const [],
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> float;

  const _PageContent({required this.page, required this.float});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          // Illustration with gentle floating animation
          AnimatedBuilder(
            animation: float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (float.value - 0.5) * 14),
              child: child,
            ),
            child: Container(
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
                        errorBuilder: (_, _, _) => Icon(
                          page.icon,
                          size: 90,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : _FeatureIllustration(page: page),
            ),
          ),
          const SizedBox(height: 40),
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
          if (page.highlights.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...page.highlights.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
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

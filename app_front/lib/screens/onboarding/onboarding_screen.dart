import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../providers/locale_provider.dart';

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

  // Page text is stored as translation keys and resolved with LocaleProvider.t
  // at render time (see _PageContent.build).
  static const _pages = [
    _OnboardingPage(
      gradient: [Color(0xFF0E7A23), Color(0xFF1AAF3C)],
      icon: Icons.landscape_rounded,
      titleKey: 'onb.p1.title',
      subtitleKey: 'onb.p1.subtitle',
      imagePath: 'assets/images/logo.png',
      isLogo: true,
      highlightKeys: [
        'onb.p1.hl1',
        'onb.p1.hl2',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFF1565C0), Color(0xFF0288D1)],
      icon: Icons.map_rounded,
      titleKey: 'onb.p2.title',
      subtitleKey: 'onb.p2.subtitle',
      imagePath: null,
      isLogo: false,
      highlightKeys: [
        'onb.p2.hl1',
        'onb.p2.hl2',
        'onb.p2.hl3',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      icon: Icons.hiking_rounded,
      titleKey: 'onb.p3.title',
      subtitleKey: 'onb.p3.subtitle',
      imagePath: null,
      isLogo: false,
      highlightKeys: [
        'onb.p3.hl1',
        'onb.p3.hl2',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFFE65100), Color(0xFFFF8F00)],
      icon: Icons.quiz_rounded,
      titleKey: 'onb.p4.title',
      subtitleKey: 'onb.p4.subtitle',
      imagePath: null,
      isLogo: false,
      highlightKeys: [
        'onb.p4.hl1',
        'onb.p4.hl2',
      ],
    ),
    _OnboardingPage(
      gradient: [Color(0xFFC62828), Color(0xFFE53935)],
      icon: Icons.sos_rounded,
      titleKey: 'onb.p5.title',
      subtitleKey: 'onb.p5.subtitle',
      imagePath: null,
      isLogo: false,
      highlightKeys: [
        'onb.p5.hl1',
        'onb.p5.hl2',
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
    final lp = context.watch<LocaleProvider>();
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
                        widget.isReplay ? lp.t('onb.close') : lp.t('onb.skip'),
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
                                  ? (widget.isReplay
                                        ? lp.t('onb.done')
                                        : lp.t('onb.start'))
                                  : lp.t('onb.next'),
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
  // Translation keys (resolved via LocaleProvider.t at render time).
  final String titleKey;
  final String subtitleKey;
  final String? imagePath;
  final bool isLogo;
  final List<String> highlightKeys;

  const _OnboardingPage({
    required this.gradient,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.imagePath,
    required this.isLogo,
    this.highlightKeys = const [],
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> float;

  const _PageContent({required this.page, required this.float});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
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
            lp.t(page.titleKey),
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
            lp.t(page.subtitleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
          ),
          if (page.highlightKeys.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...page.highlightKeys.map(
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
                        lp.t(h),
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

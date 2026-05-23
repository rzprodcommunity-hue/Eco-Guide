import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0;

  late final AnimationController _orbitCtrl;
  late final AnimationController _contentCtrl;

  // Theme colors — Eco-Guide forest green palette
  static const Color _bgDeep = Color(0xFF071810);
  static const Color _bgMid = Color(0xFF0F2E1A);
  static const Color _bgTop = Color(0xFF184D2A);
  static const Color _accent = Color(0xFF1AAF3C);
  static const Color _accentSoft = Color(0xFF7BC97F);

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.eco_rounded,
      title: 'Bienvenue sur Eco-Guide',
      subtitle:
          'Votre compagnon intelligent pour explorer la nature algérienne en toute sécurité.',
      imagePath: 'assets/images/logo.png',
      isLogo: true,
      orbitIcons: [
        Icons.spa_rounded,
        Icons.park_rounded,
        Icons.local_florist_rounded,
        Icons.energy_savings_leaf_rounded,
      ],
      tagline: 'Explorez · Découvrez · Protégez',
    ),
    _OnboardingPage(
      icon: Icons.map_rounded,
      title: 'Carte Interactive',
      subtitle:
          'Explorez les sentiers et points d\'intérêt sur une carte détaillée. Fonctionne même hors connexion.',
      imagePath: null,
      isLogo: false,
      orbitIcons: [
        Icons.location_on_rounded,
        Icons.explore_rounded,
        Icons.navigation_rounded,
        Icons.pin_drop_rounded,
      ],
      tagline: 'Géolocalisation · Hors-ligne · Précis',
    ),
    _OnboardingPage(
      icon: Icons.hiking_rounded,
      title: 'Sentiers & POIs',
      subtitle:
          'Découvrez des sentiers classés par difficulté et des points d\'intérêt naturels et culturels.',
      imagePath: null,
      isLogo: false,
      orbitIcons: [
        Icons.terrain_rounded,
        Icons.forest_rounded,
        Icons.landscape_rounded,
        Icons.directions_walk_rounded,
      ],
      tagline: 'Facile · Modéré · Expert',
    ),
    _OnboardingPage(
      icon: Icons.quiz_rounded,
      title: 'Quiz Nature',
      subtitle:
          'Testez vos connaissances sur la faune, la flore et l\'écologie. Gagnez des badges et grimpez au classement.',
      imagePath: null,
      isLogo: false,
      orbitIcons: [
        Icons.emoji_events_rounded,
        Icons.workspace_premium_rounded,
        Icons.psychology_rounded,
        Icons.lightbulb_rounded,
      ],
      tagline: 'Apprendre · Jouer · Gagner',
    ),
    _OnboardingPage(
      icon: Icons.shield_rounded,
      title: 'SOS & Sécurité',
      subtitle:
          'Envoyez une alerte d\'urgence géolocalisée en un seul geste, même sans connexion internet.',
      imagePath: null,
      isLogo: false,
      orbitIcons: [
        Icons.sos_rounded,
        Icons.health_and_safety_rounded,
        Icons.notifications_active_rounded,
        Icons.gps_fixed_rounded,
      ],
      tagline: 'Rapide · Géolocalisé · Sécurisé',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _contentCtrl.forward();

    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0;
      });
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (ctx, animation, secondary) => const AppWrapper(),
        transitionsBuilder: (ctx, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    _contentCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orbitCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Deep green vertical gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgMid, _bgDeep],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Radial glow behind illustration (depth layer)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _orbitCtrl,
                builder: (_, _) {
                  final t = _orbitCtrl.value * 2 * math.pi;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          math.sin(t) * 0.25,
                          -0.25 + math.cos(t) * 0.1,
                        ),
                        radius: 0.9,
                        colors: [
                          _accent.withValues(alpha: 0.32),
                          _accent.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3D floating particles (depth field)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _orbitCtrl,
                builder: (_, _) => CustomPaint(
                  painter: _ParticleFieldPainter(
                    progress: _orbitCtrl.value,
                    color: _accentSoft,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color: _accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'EcoGuide',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Passer',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3D PageView with perspective transforms
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (_, i) {
                      final delta = i - _pageOffset;
                      final absDelta = delta.abs().clamp(0.0, 1.0);
                      // 3D perspective rotation
                      final rotY = delta * 0.55;
                      final scale = 1 - absDelta * 0.12;
                      final opacity = 1 - absDelta * 0.4;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014) // perspective
                          ..rotateY(rotY)
                          ..scaleByDouble(scale, scale, 1.0, 1.0),
                        child: Opacity(
                          opacity: opacity,
                          child: _PageContent(
                            page: _pages[i],
                            controller: _contentCtrl,
                            orbitCtrl: _orbitCtrl,
                            isActive: i == _currentPage,
                            parallax: delta,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Progress bar + dots
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 18),
                  child: Row(
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerLeft,
                            widthFactor:
                                active ? 1.0 : (i < _currentPage ? 1.0 : 0.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [_accent, _accentSoft],
                                ),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color:
                                              _accent.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 0.5,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // CTA row
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 36),
                  child: Row(
                    children: [
                      // Back button (3D pill)
                      _GhostButton(
                        icon: Icons.arrow_back_rounded,
                        enabled: _currentPage > 0,
                        onTap: () {
                          if (_currentPage > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        },
                      ),
                      const Spacer(),
                      _PremiumCtaButton(
                        label: isLast ? 'Commencer' : 'Suivant',
                        icon: isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        onTap: _next,
                        orbitCtrl: _orbitCtrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imagePath;
  final bool isLogo;
  final List<IconData> orbitIcons;
  final String tagline;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.isLogo,
    required this.orbitIcons,
    required this.tagline,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final AnimationController controller;
  final AnimationController orbitCtrl;
  final bool isActive;
  final double parallax;

  const _PageContent({
    required this.page,
    required this.controller,
    required this.orbitCtrl,
    required this.isActive,
    required this.parallax,
  });

  @override
  Widget build(BuildContext context) {
    final fadeIllu = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    final scaleIllu = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    final slideTitle = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    final fadeTitle = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.30, 0.75, curve: Curves.easeIn),
    );
    final slideTagline = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    final fadeTagline = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.5, 0.85, curve: Curves.easeIn),
    );
    final slideSub = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    final fadeSub = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 3D illustration with parallax depth
          Transform.translate(
            offset: Offset(-parallax * 30, 0),
            child: FadeTransition(
              opacity: fadeIllu,
              child: ScaleTransition(
                scale: scaleIllu,
                child: _Orbit3DIllustration(
                  page: page,
                  orbitCtrl: orbitCtrl,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          // Tagline pill
          SlideTransition(
            position: slideTagline,
            child: FadeTransition(
              opacity: fadeTagline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _OnboardingScreenState._accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _OnboardingScreenState._accent
                        .withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  page.tagline,
                  style: const TextStyle(
                    color: _OnboardingScreenState._accentSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Title
          SlideTransition(
            position: slideTitle,
            child: FadeTransition(
              opacity: fadeTitle,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Colors.white,
                    _OnboardingScreenState._accentSoft,
                  ],
                ).createShader(rect),
                child: Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Subtitle
          SlideTransition(
            position: slideSub,
            child: FadeTransition(
              opacity: fadeSub,
              child: Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orbit3DIllustration extends StatelessWidget {
  final _OnboardingPage page;
  final AnimationController orbitCtrl;

  const _Orbit3DIllustration({required this.page, required this.orbitCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: AnimatedBuilder(
        animation: orbitCtrl,
        builder: (context, _) {
          final t = orbitCtrl.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer 3D tilted ring (back)
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(math.pi / 3.2)
                  ..rotateZ(t * 0.4),
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _RingPainter(
                    color: _OnboardingScreenState._accent
                        .withValues(alpha: 0.35),
                    strokeWidth: 1.2,
                  ),
                ),
              ),

              // Middle tilted dashed ring
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(math.pi / 3.6)
                  ..rotateZ(-t * 0.7),
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: _DashedRingPainter(
                    color: _OnboardingScreenState._accentSoft
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),

              // Orbiting icons on tilted plane (true 3D feel)
              ...List.generate(page.orbitIcons.length, (i) {
                final angle =
                    t * 0.9 + (i * 2 * math.pi / page.orbitIcons.length);
                final radius = 110.0;
                final x = math.cos(angle) * radius;
                // Tilt the plane: y is scaled (cos tilt) and z gives depth
                final tiltAngle = math.pi / 3.2;
                final yPlane = math.sin(angle) * radius;
                final y = yPlane * math.cos(tiltAngle);
                final z = yPlane * math.sin(tiltAngle);
                // depth: z>0 = closer to viewer (bigger, brighter)
                final depth = (z + radius) / (2 * radius); // 0..1
                final iconScale = 0.55 + depth * 0.55;
                final iconOpacity = 0.35 + depth * 0.6;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..translateByDouble(x, y, z, 1.0),
                  child: Transform.scale(
                    scale: iconScale,
                    child: Opacity(
                      opacity: iconOpacity.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              _OnboardingScreenState._accent
                                  .withValues(alpha: 0.25),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _OnboardingScreenState._accent
                                  .withValues(alpha: 0.35 * depth),
                              blurRadius: 14,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Icon(
                          page.orbitIcons[i],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Central 3D glass sphere
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(math.sin(t) * 0.18)
                  ..rotateX(math.cos(t) * 0.10),
                child: _GlassSphere(page: page),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassSphere extends StatelessWidget {
  final _OnboardingPage page;
  const _GlassSphere({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            _OnboardingScreenState._accent.withValues(alpha: 0.55),
            _OnboardingScreenState._bgMid.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _OnboardingScreenState._accent.withValues(alpha: 0.55),
            blurRadius: 36,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy highlight
          Positioned(
            top: 14,
            left: 22,
            child: Container(
              width: 36,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Icon or logo in center
          Center(
            child: page.isLogo && page.imagePath != null
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Image.asset(
                      page.imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.eco_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    page.icon,
                    size: 60,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _RingPainter({required this.color, this.strokeWidth = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const dashCount = 32;
    const sweepPerDash = (2 * math.pi) / dashCount;
    const dashFraction = 0.5;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweepPerDash,
        sweepPerDash * dashFraction,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ParticleFieldPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 40; i++) {
      final baseX = rng.nextDouble();
      final baseY = rng.nextDouble();
      final depth = rng.nextDouble(); // 0..1, smaller = farther
      final speed = 0.15 + depth * 0.35;
      final dy = ((baseY + progress * speed) % 1.0);
      final dx = baseX + math.sin((progress + i) * 2 * math.pi) * 0.02;
      final radius = 0.6 + depth * 2.4;
      paint.color = color.withValues(alpha: 0.10 + depth * 0.45);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter old) =>
      old.progress != progress;
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _GhostButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PremiumCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AnimationController orbitCtrl;

  const _PremiumCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.orbitCtrl,
  });

  @override
  State<_PremiumCtaButton> createState() => _PremiumCtaButtonState();
}

class _PremiumCtaButtonState extends State<_PremiumCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: AnimatedBuilder(
          animation: widget.orbitCtrl,
          builder: (_, _) {
            final t = widget.orbitCtrl.value * 2 * math.pi;
            final glow = 0.4 + 0.25 * ((math.sin(t * 2) + 1) / 2);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _OnboardingScreenState._accent,
                    _OnboardingScreenState._accentSoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _OnboardingScreenState._accent
                        .withValues(alpha: glow),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

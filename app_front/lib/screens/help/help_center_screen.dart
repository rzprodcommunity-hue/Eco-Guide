import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';
import '../onboarding/onboarding_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.backgroundColor;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final primary = AppTheme.primaryColor;
    final textMain = isDark ? AppTheme.darkTextMain : AppTheme.textPrimary;
    final textSub = isDark ? AppTheme.darkTextSub : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          lp.t('help.title'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: lp.t('help.tab.guide')),
            Tab(text: lp.t('help.tab.faq')),
            Tab(text: lp.t('help.tab.contact')),
            Tab(text: lp.t('help.tab.tutorial')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GuideTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
          _FaqTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
          _ContactTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
          _TutorialTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
        ],
      ),
    );
  }
}

// ─── TUTORIAL TAB ────────────────────────────────────────────────────────────

class _TutorialTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _TutorialTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  void _replayTutorial(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isReplay: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    final chapters = <(IconData, Color, String, String)>[
      (Icons.landscape_rounded, const Color(0xFF0E7A23),
          lp.t('help.tutorial.c1.title'), lp.t('help.tutorial.c1.desc')),
      (Icons.map_rounded, const Color(0xFF1565C0),
          lp.t('help.tutorial.c2.title'), lp.t('help.tutorial.c2.desc')),
      (Icons.hiking_rounded, const Color(0xFF6A1B9A),
          lp.t('help.tutorial.c3.title'), lp.t('help.tutorial.c3.desc')),
      (Icons.quiz_rounded, const Color(0xFFE65100),
          lp.t('help.tutorial.c4.title'), lp.t('help.tutorial.c4.desc')),
      (Icons.sos_rounded, const Color(0xFFC62828),
          lp.t('help.tutorial.c5.title'), lp.t('help.tutorial.c5.desc')),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.school_rounded,
          title: lp.t('help.tutorial.banner.title'),
          subtitle: lp.t('help.tutorial.banner.subtitle'),
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        // Chapter list
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.darkBorder
                  : Colors.grey.withValues(alpha: 0.15),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: List.generate(chapters.length, (i) {
              final c = chapters[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.$2.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.$1, color: c.$2, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.$3,
                                style: TextStyle(
                                  color: textMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.$4,
                                style: TextStyle(
                                  color: textSub,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != chapters.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 14,
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.withValues(alpha: 0.15),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        // Replay button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _replayTutorial(context),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: Text(
              lp.t('help.tutorial.replay'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            lp.t('help.tutorial.note'),
            textAlign: TextAlign.center,
            style: TextStyle(color: textSub, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─── GUIDE TAB ───────────────────────────────────────────────────────────────

class _GuideTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _GuideTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    List<String> steps(String f) =>
        [for (var s = 1; s <= 5; s++) lp.t('help.guide.$f.s$s')];

    final features = [
      _Feature(
        icon: Icons.map_rounded,
        color: const Color(0xFF1565C0),
        title: lp.t('help.guide.f1.title'),
        steps: steps('f1'),
      ),
      _Feature(
        icon: Icons.hiking_rounded,
        color: const Color(0xFF2E7D32),
        title: lp.t('help.guide.f2.title'),
        steps: steps('f2'),
      ),
      _Feature(
        icon: Icons.place_rounded,
        color: const Color(0xFF6A1B9A),
        title: lp.t('help.guide.f3.title'),
        steps: steps('f3'),
      ),
      _Feature(
        icon: Icons.quiz_rounded,
        color: const Color(0xFFE65100),
        title: lp.t('help.guide.f4.title'),
        steps: steps('f4'),
      ),
      _Feature(
        icon: Icons.sos_rounded,
        color: const Color(0xFFC62828),
        title: lp.t('help.guide.f5.title'),
        steps: steps('f5'),
      ),
      _Feature(
        icon: Icons.store_rounded,
        color: const Color(0xFF00695C),
        title: lp.t('help.guide.f6.title'),
        steps: steps('f6'),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.menu_book_rounded,
          title: lp.t('help.guide.banner.title'),
          subtitle: lp.t('help.guide.banner.subtitle'),
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        ...features.map(
          (f) => _FeatureCard(
            feature: f,
            isDark: isDark,
            surface: surface,
            textMain: textMain,
            textSub: textSub,
          ),
        ),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> steps;

  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.steps,
  });
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  final bool isDark;
  final Color surface, textMain, textSub;

  const _FeatureCard({
    required this.feature,
    required this.isDark,
    required this.surface,
    required this.textMain,
    required this.textSub,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.darkBorder
              : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: f.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(f.icon, color: f.color, size: 22),
          ),
          title: Text(
            f.title,
            style: TextStyle(
              color: widget.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: f.color,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: List.generate(
                  f.steps.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: f.color,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.steps[i],
                            style: TextStyle(
                              color: widget.textSub,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
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
    );
  }
}

// ─── FAQ TAB ─────────────────────────────────────────────────────────────────

class _FaqTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _FaqTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    final faqs = [
      for (var i = 1; i <= 8; i++)
        _Faq(q: lp.t('help.faq.q$i'), a: lp.t('help.faq.a$i')),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.help_outline_rounded,
          title: lp.t('help.faq.banner.title'),
          subtitle: lp.t('help.faq.banner.subtitle'),
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        ...faqs.map(
          (faq) => _FaqCard(
            faq: faq,
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
        ),
      ],
    );
  }
}

class _Faq {
  final String q, a;
  const _Faq({required this.q, required this.a});
}

class _FaqCard extends StatefulWidget {
  final _Faq faq;
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _FaqCard({
    required this.faq,
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.darkBorder
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Icon(
            Icons.help_center_rounded,
            color: widget.primary,
            size: 22,
          ),
          title: Text(
            widget.faq.q,
            style: TextStyle(
              color: widget.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: widget.primary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.faq.a,
                  style: TextStyle(
                    color: widget.textSub,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CONTACT TAB ─────────────────────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _ContactTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.contact_support_rounded,
          title: lp.t('help.contact.banner.title'),
          subtitle: lp.t('help.contact.banner.subtitle'),
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _ContactCard(
          icon: Icons.email_rounded,
          color: const Color(0xFF1565C0),
          title: lp.t('help.contact.email.title'),
          subtitle: 'support@ecoguide.dz',
          detail: lp.t('help.contact.email.detail'),
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFC62828),
          title: lp.t('help.contact.bug.title'),
          subtitle: 'bugs@ecoguide.dz',
          detail: lp.t('help.contact.bug.detail'),
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFE65100),
          title: lp.t('help.contact.feature.title'),
          subtitle: 'feedback@ecoguide.dz',
          detail: lp.t('help.contact.feature.detail'),
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lp.t('help.contact.footer'),
                  style: TextStyle(
                    color: textSub,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, detail;
  final bool isDark;
  final Color surface, textMain, textSub;

  const _ContactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.isDark,
    required this.surface,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? AppTheme.darkBorder : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 12,
                    height: 1.4,
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

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class _SectionBanner extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color primary;
  final bool isDark;

  const _SectionBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.4,
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

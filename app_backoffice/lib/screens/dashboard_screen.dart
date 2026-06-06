import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/providers/dashboard_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/responsive.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadDashboard(),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    final stats = provider.data?.summary;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return SingleChildScrollView(
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(stats),
          SizedBox(height: isMobile ? 16 : 24),
          _buildStatsGrid(stats, isMobile: isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          if (isMobile || isTablet)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSosAlertCard(stats?.activeSosAlerts ?? 0, isMobile: isMobile),
                const SizedBox(height: 16),
                _buildChartCard(stats, isMobile: isMobile),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildChartCard(stats, isMobile: false)),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSosAlertCard(stats?.activeSosAlerts ?? 0,
                      isMobile: false),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tableau de bord',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vue d\'ensemble du contenu de l\'écosystème Eco-Guide.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(dynamic stats, {required bool isMobile}) {
    final cards = <Widget>[
      _buildStatCard(
        title: 'Utilisateurs',
        value: stats?.users?.toString() ?? '0',
        icon: Icons.people,
        color: AppColors.secondary,
        isMobile: isMobile,
      ),
      _buildStatCard(
        title: 'Sentiers',
        value: stats?.trails?.toString() ?? '0',
        icon: Icons.hiking,
        color: AppColors.primary,
        isMobile: isMobile,
      ),
      _buildStatCard(
        title: 'Points d\'intérêt',
        value: stats?.pois?.toString() ?? '0',
        icon: Icons.location_on,
        color: AppColors.warning,
        isMobile: isMobile,
      ),
      _buildStatCard(
        title: 'Quiz',
        value: stats?.quizzes?.toString() ?? '0',
        icon: Icons.quiz,
        color: Colors.purple,
        isMobile: isMobile,
      ),
      _buildStatCard(
        title: 'Services',
        value: stats?.localServices?.toString() ?? '0',
        icon: Icons.store,
        color: Colors.teal,
        isMobile: isMobile,
      ),
      _buildStatCard(
        title: 'Activités',
        value: stats?.activities?.toString() ?? '0',
        icon: Icons.timeline,
        color: Colors.indigo,
        isMobile: isMobile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Pick how many columns based on width.
        //  < 480px → 2  (true phone)
        //  480-700 → 3  (large phone / small tablet)
        //  700-1100 → 3 (tablet)
        //  >= 1100 → 6 (desktop)
        final width = constraints.maxWidth;
        final cols = width < 480 ? 2 : (width < 1100 ? 3 : 6);
        const spacing = 12.0;
        final itemWidth =
            (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (c) => SizedBox(width: itemWidth, child: c),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 22),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(dynamic stats, {required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aperçu des données',
            style: TextStyle(
              fontSize: isMobile ? 15 : 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          SizedBox(
            height: isMobile ? 220 : 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue(stats) * 1.2,
                barGroups: [
                  _makeBarGroup(0, (stats?.users ?? 0).toDouble(),
                      AppColors.secondary, isMobile),
                  _makeBarGroup(1, (stats?.trails ?? 0).toDouble(),
                      AppColors.primary, isMobile),
                  _makeBarGroup(2, (stats?.pois ?? 0).toDouble(),
                      AppColors.warning, isMobile),
                  _makeBarGroup(3, (stats?.quizzes ?? 0).toDouble(),
                      Colors.purple, isMobile),
                  _makeBarGroup(4, (stats?.localServices ?? 0).toDouble(),
                      Colors.teal, isMobile),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        const titles = [
                          'Users',
                          'Sentiers',
                          'POIs',
                          'Quiz',
                          'Services',
                        ];
                        if (value.toInt() < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              titles[value.toInt()],
                              style: TextStyle(
                                fontSize: isMobile ? 9 : 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isMobile ? 28 : 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: isMobile ? 9 : 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue(stats) / 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxValue(dynamic stats) {
    if (stats == null) return 100;
    final values = [
      stats.users ?? 0,
      stats.trails ?? 0,
      stats.pois ?? 0,
      stats.quizzes ?? 0,
      stats.localServices ?? 0,
    ];
    final max = values.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100 : max.toDouble();
  }

  BarChartGroupData _makeBarGroup(
      int x, double y, Color color, bool isMobile) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: isMobile ? 18 : 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
    );
  }

  Widget _buildSosAlertCard(int activeAlerts, {required bool isMobile}) {
    final hasAlerts = activeAlerts > 0;
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: hasAlerts
            ? AppColors.error.withValues(alpha: 0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: hasAlerts ? Border.all(color: AppColors.error, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasAlerts ? Icons.warning_amber : Icons.check_circle,
            size: isMobile ? 36 : 48,
            color: hasAlerts ? AppColors.error : AppColors.success,
          ),
          SizedBox(width: isMobile ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activeAlerts.toString(),
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: hasAlerts
                        ? AppColors.error
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Alertes SOS actives',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: hasAlerts
                        ? AppColors.error
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasAlerts) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Des utilisateurs ont besoin d\'aide.',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/providers/dashboard_provider.dart';
import '../core/constants/app_colors.dart';

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
            Text(provider.error!, style: const TextStyle(color: AppColors.error)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(stats),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildChartCard(stats),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSosAlertCard(stats?.activeSosAlerts ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(dynamic stats) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Utilisateurs',
          value: stats?.users?.toString() ?? '0',
          icon: Icons.people,
          color: AppColors.secondary,
        ),
        _buildStatCard(
          title: 'Sentiers',
          value: stats?.trails?.toString() ?? '0',
          icon: Icons.hiking,
          color: AppColors.primary,
        ),
        _buildStatCard(
          title: 'Points d\'interet',
          value: stats?.pois?.toString() ?? '0',
          icon: Icons.location_on,
          color: AppColors.warning,
        ),
        _buildStatCard(
          title: 'Quiz',
          value: stats?.quizzes?.toString() ?? '0',
          icon: Icons.quiz,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'Services Locaux',
          value: stats?.localServices?.toString() ?? '0',
          icon: Icons.store,
          color: Colors.teal,
        ),
        _buildStatCard(
          title: 'Activites',
          value: stats?.activities?.toString() ?? '0',
          icon: Icons.timeline,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(dynamic stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apercu des donnees',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue(stats) * 1.2,
                barGroups: [
                  _makeBarGroup(0, (stats?.users ?? 0).toDouble(), AppColors.secondary),
                  _makeBarGroup(1, (stats?.trails ?? 0).toDouble(), AppColors.primary),
                  _makeBarGroup(2, (stats?.pois ?? 0).toDouble(), AppColors.warning),
                  _makeBarGroup(3, (stats?.quizzes ?? 0).toDouble(), Colors.purple),
                  _makeBarGroup(4, (stats?.localServices ?? 0).toDouble(), Colors.teal),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Users', 'Trails', 'POIs', 'Quiz', 'Services'];
                        if (value.toInt() < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              titles[value.toInt()],
                              style: const TextStyle(fontSize: 12),
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
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 32,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
    );
  }

  Widget _buildSosAlertCard(int activeAlerts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: activeAlerts > 0 ? AppColors.error.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: activeAlerts > 0 ? Border.all(color: AppColors.error, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            activeAlerts > 0 ? Icons.warning_amber : Icons.check_circle,
            size: 64,
            color: activeAlerts > 0 ? AppColors.error : AppColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            activeAlerts.toString(),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: activeAlerts > 0 ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Alertes SOS actives',
            style: TextStyle(
              fontSize: 16,
              color: activeAlerts > 0 ? AppColors.error : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (activeAlerts > 0) ...[
            const SizedBox(height: 16),
            const Text(
              'Attention! Des utilisateurs ont besoin d\'aide.',
              style: TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

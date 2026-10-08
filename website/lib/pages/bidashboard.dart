import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:website/src/heritage_theme.dart';

class Bidashboard extends StatefulWidget {
  const Bidashboard({super.key});

  @override
  State<Bidashboard> createState() => _BidashboardState();
}

class _BidashboardState extends State<Bidashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Dashboard data
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _artifactsBySite = [];
  List<Map<String, dynamic>> _submissionsOverTime = [];
  List<Map<String, dynamic>> _topContributors = [];
  List<Map<String, dynamic>> _submissionsByMonth = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final supabase = Supabase.instance.client;
      final heritageSites = await supabase
          .from('heritage_sites')
          .select('id, name, description');
      final artifacts = await supabase
          .from('artifacts')
          .select(
            'id, heritage_site_id, submitted_at, user_name, cultural_narrative',
          );

      final totalArtifacts = artifacts.length;
      final totalSites = heritageSites.length;
      final artifactsCountMap = <String, int>{};
      for (final site in heritageSites) {
        artifactsCountMap[site['name']] = 0;
      }
      for (final artifact in artifacts) {
        final site = heritageSites.firstWhere(
          (item) => item['id'] == artifact['heritage_site_id'],
          orElse: () => {'name': 'Unknown'},
        );
        final siteName = site['name'];
        artifactsCountMap[siteName] = (artifactsCountMap[siteName] ?? 0) + 1;
      }
      _artifactsBySite =
          artifactsCountMap.entries
              .map((entry) => {'name': entry.key, 'count': entry.value})
              .where((entry) => (entry['count'] as int) > 0)
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final submissionsByMonth = <String, int>{};
      final submissionsByDay = <String, int>{};
      final contributorCounts = <String, int>{};
      for (final artifact in artifacts) {
        final date = DateTime.parse(artifact['submitted_at']);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final dayKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        submissionsByMonth[monthKey] = (submissionsByMonth[monthKey] ?? 0) + 1;
        submissionsByDay[dayKey] = (submissionsByDay[dayKey] ?? 0) + 1;
        final name = artifact['user_name'] ?? 'Anonymous';
        contributorCounts[name] = (contributorCounts[name] ?? 0) + 1;
      }

      _submissionsByMonth =
          submissionsByMonth.entries
              .map((entry) => {'month': entry.key, 'count': entry.value})
              .toList()
            ..sort(
              (a, b) => (a['month'] as String).compareTo(b['month'] as String),
            );
      _submissionsOverTime =
          submissionsByDay.entries
              .map((entry) => {'date': entry.key, 'count': entry.value})
              .toList()
            ..sort(
              (a, b) => (a['date'] as String).compareTo(b['date'] as String),
            );
      _topContributors =
          contributorCounts.entries
              .where((entry) => entry.key != 'Anonymous')
              .map((entry) => {'name': entry.key, 'count': entry.value})
              .toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      _dashboardData = {
        'totalArtifacts': totalArtifacts,
        'totalSites': totalSites,
        'avgArtifactsPerSite': totalSites > 0 ? totalArtifacts / totalSites : 0,
        'mostActiveSite': _artifactsBySite.isNotEmpty
            ? _artifactsBySite.first['name']
            : 'None',
        'recentSubmissions': _submissionsOverTime.length,
      };
      setState(() => _isLoading = false);
    } catch (error) {
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: HeritagePalette.forest,
          secondary: HeritagePalette.red,
          surface: HeritagePalette.surface,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: GoogleFonts.manrope().fontFamily),
      ),
      child: Scaffold(
        backgroundColor: HeritagePalette.canvas,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                20,
                isMobile ? 16 : 32,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildStatsGrid(isMobile),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            _buildLoadingState()
                          else if (_hasError)
                            _buildErrorState()
                          else
                            Column(
                              children: [
                                if (isMobile) ...[
                                  _buildSubmissionsTrend(),
                                  const SizedBox(height: 16),
                                  _buildMonthlyDistributionChart(),
                                  const SizedBox(height: 16),
                                  _buildArtifactsBySiteChart(),
                                  const SizedBox(height: 16),
                                  _buildTopContributors(),
                                ] else ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildSubmissionsTrend(),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: _buildMonthlyDistributionChart(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _buildArtifactsBySiteChart(),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(child: _buildTopContributors()),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 18),
                                _buildEnhancedInsightsPanel(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeritageTricolorBand(height: 6),
          Container(
            color: HeritagePalette.forest,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVING HERITAGE  /  INSIGHTS',
                  style: GoogleFonts.spaceGrotesk(
                    color: HeritagePalette.sun,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A picture of heritage activity',
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submissions, sites and community participation.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 0.9 : 1.65,
      children: [
        _buildAnimatedStatCard(
          'Total Artifacts',
          _dashboardData['totalArtifacts']?.toString() ?? '0',
          Icons.photo_library,
          HeritagePalette.forest,
          'collected',
        ),
        _buildAnimatedStatCard(
          'Heritage Sites',
          _dashboardData['totalSites']?.toString() ?? '0',
          Icons.forest,
          HeritagePalette.red,
          'protected',
        ),
        _buildAnimatedStatCard(
          'Avg Artifacts/Site',
          _dashboardData['avgArtifactsPerSite']?.toStringAsFixed(1) ?? '0',
          Icons.bar_chart,
          HeritagePalette.sun,
          'per site',
        ),
        _buildAnimatedStatCard(
          'Most Active Site',
          _dashboardData['mostActiveSite'] ?? 'None',
          Icons.emoji_events,
          HeritagePalette.ink,
          'leader',
        ),
      ],
    );
  }

  Widget _buildAnimatedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Container(
            decoration: BoxDecoration(
              color: HeritagePalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HeritagePalette.rule),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: HeritagePalette.forest,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HeritagePalette.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyDistributionChart() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HeritagePalette.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Monthly Distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: _submissionsByMonth.isEmpty
                  ? const Center(child: Text('No data available'))
                  : CustomPaint(
                      painter: PieChartPainter(
                        data: _submissionsByMonth
                            .map((e) => e['count'] as int)
                            .toList(),
                        labels: _submissionsByMonth.map((e) {
                          final month = e['month'].toString().split('-')[1];
                          final monthNames = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec',
                          ];
                          return monthNames[int.parse(month) - 1];
                        }).toList(),
                      ),
                      size: const Size(double.infinity, 280),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionsTrend() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HeritagePalette.forest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Submissions Trend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Daily',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
              child: _submissionsOverTime.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No submission data yet',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start submitting artifacts to see trends',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomPaint(
                          painter: EnhancedLineChartPainter(
                            data: _submissionsOverTime
                                .map((e) => e['count'] as int)
                                .toList(),
                            labels: _submissionsOverTime
                                .map((e) => e['date'].toString())
                                .toList(),
                          ),
                          size: Size(constraints.maxWidth, 280),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtifactsBySiteChart() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HeritagePalette.sun,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: HeritagePalette.ink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Artifacts by Heritage Site',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: _artifactsBySite.isEmpty
                  ? const Center(child: Text('No data available'))
                  : ListView.builder(
                      itemCount: _artifactsBySite.length,
                      itemBuilder: (context, index) {
                        final site = _artifactsBySite[index];
                        final count = site['count'] as int;
                        final maxCount = _artifactsBySite.isNotEmpty
                            ? (_artifactsBySite[0]['count'] as int)
                            : 1;
                        final double percentage = maxCount > 0
                            ? (count / maxCount)
                            : 0.0;

                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: percentage),
                          duration: Duration(milliseconds: 500 + (index * 100)),
                          builder: (context, double animValue, child) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          site['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: HeritagePalette.sun.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: HeritagePalette.forest,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: animValue,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        HeritagePalette.forest,
                                      ),
                                      minHeight: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopContributors() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HeritagePalette.ink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Top Contributors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_topContributors.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No contributors yet'),
                    ],
                  ),
                ),
              )
            else
              ..._topContributors.take(5).map((contributor) {
                final name = contributor['name'];
                final count = contributor['count'];
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300),
                  builder: (context, double animValue, child) {
                    return Opacity(
                      opacity: animValue,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - animValue)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: HeritagePalette.forest,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$count submissions',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: HeritagePalette.sun,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${_topContributors.indexOf(contributor) + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: HeritagePalette.ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedInsightsPanel() {
    final totalSubmissions = _submissionsOverTime.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    final totalSitesWithArtifacts = _artifactsBySite.length;
    final topSite = _artifactsBySite.isNotEmpty
        ? _artifactsBySite[0]['name']
        : 'None';
    final topSiteCount = _artifactsBySite.isNotEmpty
        ? _artifactsBySite[0]['count']
        : 0;
    final totalContributors = _topContributors.length;

    String trendText = 'No data yet';
    if (_submissionsOverTime.length >= 2) {
      // FIXED: Properly calculate recent and older averages without negative skip values
      final recentCount = _submissionsOverTime.length >= 3
          ? 3
          : _submissionsOverTime.length;
      final olderCount = _submissionsOverTime.length >= 3
          ? 3
          : _submissionsOverTime.length;

      final recentAvg =
          _submissionsOverTime
              .take(recentCount)
              .fold<int>(0, (sum, item) => sum + (item['count'] as int)) /
          recentCount;

      final olderAvg =
          _submissionsOverTime
              .skip(_submissionsOverTime.length - olderCount)
              .fold<int>(0, (sum, item) => sum + (item['count'] as int)) /
          olderCount;

      if (recentAvg > olderAvg) {
        trendText = 'Submissions are increasing 📈';
      } else if (recentAvg < olderAvg) {
        trendText = 'Submissions are decreasing 📉';
      } else {
        trendText = 'Submissions are steady 📊';
      }
    } else if (totalSubmissions > 0) {
      trendText =
          '${totalSubmissions} total submission${totalSubmissions != 1 ? 's' : ''} recorded';
    }

    String recommendationText = '';
    if (totalSitesWithArtifacts == 0) {
      recommendationText =
          'Start by submitting artifacts to build your knowledge graph';
    } else if (totalSitesWithArtifacts < 3) {
      recommendationText =
          'Focus on underrepresented heritage sites to diversify data';
    } else if (totalSubmissions < 10) {
      recommendationText = 'Increase submissions to get more insights';
    } else {
      recommendationText = 'Great distribution! Continue expanding coverage';
    }

    return Container(
      decoration: BoxDecoration(
        color: HeritagePalette.surface,
        border: Border.all(color: HeritagePalette.rule),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HeritagePalette.sun.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: HeritagePalette.ink,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Key insights',
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: HeritagePalette.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 1 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: [
                _buildEnhancedInsightCard(
                  '📈 Growth Trend',
                  trendText,
                  HeritagePalette.red,
                  Icons.trending_up,
                ),
                _buildEnhancedInsightCard(
                  '🏆 Top Site',
                  topSite != 'None'
                      ? '$topSite leads with $topSiteCount artifact${topSiteCount != 1 ? 's' : ''}'
                      : 'No artifacts submitted yet',
                  HeritagePalette.sun,
                  Icons.emoji_events,
                ),
                _buildEnhancedInsightCard(
                  '👥 Community',
                  totalContributors > 0
                      ? '$totalContributors active contributor${totalContributors != 1 ? 's' : ''} driving engagement'
                      : 'Be the first contributor!',
                  HeritagePalette.ink,
                  Icons.people,
                ),
                _buildEnhancedInsightCard(
                  '🎯 Recommendation',
                  recommendationText,
                  HeritagePalette.forest,
                  Icons.lightbulb_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedInsightCard(
    String title,
    String description,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HeritagePalette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HeritagePalette.rule),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.forest,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard data...',
              style: TextStyle(color: Colors.green.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Line Chart Painter with proper error handling
class EnhancedLineChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;

  EnhancedLineChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    if (data.length == 1) {
      _drawSinglePoint(canvas, size);
      return;
    }

    _drawFullChart(canvas, size);
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'No submission data',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, size.height / 2),
    );
  }

  void _drawSinglePoint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = Colors.green.shade600
      ..style = PaintingStyle.fill;

    final height = size.height - 60;
    final width = size.width - 40;
    final startX = 20.0;
    final centerX = startX + width / 2;
    final centerY = height / 2 + 30;

    canvas.drawCircle(Offset(centerX, centerY), 8, pointPaint);
    canvas.drawCircle(
      Offset(centerX, centerY),
      4,
      Paint()..color = Colors.white,
    );

    final label = labels[0];
    final dateParts = label.split('-');
    final displayLabel = dateParts.length >= 3
        ? '${dateParts[1]}/${dateParts[2]}'
        : label;

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayLabel,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, size.height - 20),
    );

    final valuePainter = TextPainter(
      text: TextSpan(
        text: '${data[0]} submission${data[0] != 1 ? 's' : ''}',
        style: TextStyle(
          color: Colors.green.shade600,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    valuePainter.layout();
    valuePainter.paint(
      canvas,
      Offset(centerX - valuePainter.width / 2, centerY - 20),
    );
  }

  void _drawFullChart(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.green.shade600
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce(math.max).toDouble();
    final minValue = data.reduce(math.min).toDouble();
    final range = maxValue - minValue;
    final height = size.height - 60;
    final width = size.width - 40;
    final startX = 20.0;
    final step = width / (data.length - 1);

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = startX + (i * step);
      final y =
          height -
          ((data[i] - minValue) / (range == 0 ? 1 : range)) * height +
          30;
      points.add(Offset(x, y.clamp(30.0, size.height - 30)));
    }

    final path = Path();
    path.moveTo(startX, size.height - 30);
    for (var point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(points.last.dx, size.height - 30);
    path.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.green.shade600.withOpacity(0.3),
          Colors.green.shade600.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, gradientPaint);

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    for (var point in points) {
      canvas.drawCircle(point, 6, pointPaint);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = 30 + (height / 4) * i;
      canvas.drawLine(Offset(startX, y), Offset(startX + width, y), gridPaint);

      final value = minValue + (range / 4) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(startX - 25, y - textPainter.height / 2),
      );
    }

    for (int i = 0; i < data.length; i++) {
      final x = startX + (i * step);
      final label = labels[i];
      final dateParts = label.split('-');
      final displayLabel = dateParts.length >= 3
          ? '${dateParts[1]}/${dateParts[2]}'
          : label;

      final textPainter = TextPainter(
        text: TextSpan(
          text: displayLabel,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedLineChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

// Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;

  PieChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final total = data.reduce((a, b) => a + b).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    double startAngle = -math.pi / 2;

    const colors = [
      HeritagePalette.forest,
      HeritagePalette.red,
      HeritagePalette.sun,
      HeritagePalette.ink,
    ];

    // Draw pie slices
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw legend
    double legendY = 20;
    for (int i = 0; i < data.length && i < 5; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawRect(Rect.fromLTWH(size.width - 80, legendY, 12, 12), paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ${labels[i]} (${data[i]})',
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 65, legendY - 2));
      legendY += 20;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

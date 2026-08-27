import 'package:flutter/material.dart';
import '../../../core/services/admin_stats_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AdminStatsService _statsService = AdminStatsService();

  late Future<AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<AdminStats> _loadStats() {
    return _statsService.getStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });

    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<AdminStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ErrorView(
                  onRetry: _refresh,
                  error: snapshot.error.toString(),
                );
              }

              final stats = snapshot.data;

              if (stats == null) {
                return const Center(child: Text('No statistics available.'));
              }

              return _DashboardContent(stats: stats, onRefresh: _refresh);
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DASHBOARD CONTENT
// ============================================================================

class _DashboardContent extends StatelessWidget {
  final AdminStats stats;
  final Future<void> Function() onRefresh;

  const _DashboardContent({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final isMedium = constraints.maxWidth >= 700;

        final columns = isWide
            ? 4
            : isMedium
            ? 2
            : 1;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isWide ? 32 : 24),
          children: [
            // ============================================================
            // HEADER
            // ============================================================
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Overview of your MediData platform',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============================================================
            // MAIN STATISTICS
            // ============================================================
            Text(
              'Platform Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 2.0 : 1.8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Users',
                  value: stats.users,
                  icon: Icons.people_alt_rounded,
                ),
                _StatCard(
                  title: 'Academic Levels',
                  value: stats.academicLevels,
                  icon: Icons.school_rounded,
                ),
                _StatCard(
                  title: 'Modules',
                  value: stats.modules,
                  icon: Icons.menu_book_rounded,
                ),
                _StatCard(
                  title: 'Main Lectures',
                  value: stats.lectures,
                  icon: Icons.play_circle_fill_rounded,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============================================================
            // LECTURES
            // ============================================================
            Text(
              'Lectures',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 2.0 : 1.8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Main Lectures',
                  value: stats.lectures,
                  icon: Icons.video_library_rounded,
                ),
                _StatCard(
                  title: 'Published Lectures',
                  value: stats.publishedLectures,
                  icon: Icons.publish_rounded,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============================================================
            // FILES
            // ============================================================
            Text(
              'Files',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isWide ? 2.0 : 1.8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Total Files',
                  value: stats.files,
                  icon: Icons.folder_rounded,
                  large: true,
                ),
                _StatCard(
                  title: 'PDF',
                  value: stats.pdfFiles,
                  icon: Icons.picture_as_pdf_rounded,
                ),
                _StatCard(
                  title: 'Audio',
                  value: stats.audioFiles,
                  icon: Icons.audio_file_rounded,
                ),
                _StatCard(
                  title: 'Video',
                  value: stats.videoFiles,
                  icon: Icons.video_file_rounded,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ============================================================
            // CONTENT DISTRIBUTION
            // ============================================================
            Text(
              'Content Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            _ContentDistributionCard(
              pdf: stats.pdfFiles,
              audio: stats.audioFiles,
              video: stats.videoFiles,
              total: stats.files,
            ),

            const SizedBox(height: 28),

            // ============================================================
            // CONTENT OVERVIEW
            // ============================================================
            Text(
              'Content Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Main lectures are counted separately '
                        'from their attached files. PDF, audio '
                        'and video statistics are calculated '
                        'from the lecture_files table.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final bool large;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(large ? 28 : 22),
        child: Row(
          children: [
            Container(
              width: large ? 58 : 52,
              height: large ? 58 : 52,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primary, size: large ? 30 : 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENT DISTRIBUTION
// ============================================================================

class _ContentDistributionCard extends StatelessWidget {
  final int pdf;
  final int audio;
  final int video;
  final int total;

  const _ContentDistributionCard({
    required this.pdf,
    required this.audio,
    required this.video,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pdfRatio = total > 0 ? pdf / total : 0.0;
    final audioRatio = total > 0 ? audio / total : 0.0;
    final videoRatio = total > 0 ? video / total : 0.0;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // TOTAL
            // ============================================================
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.insert_drive_file_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Content Files',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.60,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        total.toString(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ============================================================
            // DISTRIBUTION BAR
            // ============================================================
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (pdf > 0)
                      Expanded(
                        flex: pdf,
                        child: Container(color: Colors.red.shade400),
                      ),
                    if (audio > 0)
                      Expanded(
                        flex: audio,
                        child: Container(color: Colors.orange.shade400),
                      ),
                    if (video > 0)
                      Expanded(
                        flex: video,
                        child: Container(color: Colors.blue.shade400),
                      ),
                    if (total == 0)
                      Expanded(
                        child: Container(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ============================================================
            // PDF
            // ============================================================
            _DistributionRow(
              icon: Icons.picture_as_pdf_rounded,
              title: 'PDF',
              value: pdf,
              percentage: pdfRatio,
              color: Colors.red.shade400,
            ),

            const SizedBox(height: 14),

            // ============================================================
            // AUDIO
            // ============================================================
            _DistributionRow(
              icon: Icons.audio_file_rounded,
              title: 'Audio',
              value: audio,
              percentage: audioRatio,
              color: Colors.orange.shade400,
            ),

            const SizedBox(height: 14),

            // ============================================================
            // VIDEO
            // ============================================================
            _DistributionRow(
              icon: Icons.video_file_rounded,
              title: 'Video',
              value: video,
              percentage: videoRatio,
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DISTRIBUTION ROW
// ============================================================================

class _DistributionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final double percentage;
  final Color color;

  const _DistributionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$value',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.07,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String error;

  const _ErrorView({required this.onRetry, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 60,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load dashboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check the Supabase connection.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            if (error.isNotEmpty)
              SelectableText(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

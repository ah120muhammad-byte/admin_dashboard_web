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

  Future<AdminStats> _loadStats() => _statsService.getStats();

  Future<void> _refresh() async {
    setState(() => _statsFuture = _loadStats());
    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorView(
            error: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final stats = snapshot.data;
        if (stats == null) {
          return const Center(child: Text('No statistics available.'));
        }

        return _DashboardContent(stats: stats, onRefresh: _refresh);
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final AdminStats stats;
  final Future<void> Function() onRefresh;

  const _DashboardContent({
    required this.stats,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1150;
        final medium = constraints.maxWidth >= 760;
        final columns = wide ? 4 : (medium ? 2 : 1);
        final horizontalPadding = wide ? 32.0 : 24.0;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              32,
            ),
            children: [
              _WelcomeHeader(onRefresh: onRefresh),
              const SizedBox(height: 28),
              Text(
                'Platform Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: wide ? 2.15 : 1.9,
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
              Text(
                'Content',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: wide ? 2.15 : 1.9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    title: 'Published Lectures',
                    value: stats.publishedLectures,
                    icon: Icons.publish_rounded,
                  ),
                  _StatCard(
                    title: 'Total Files',
                    value: stats.files,
                    icon: Icons.folder_rounded,
                  ),
                  _StatCard(
                    title: 'PDF Files',
                    value: stats.pdfFiles,
                    icon: Icons.picture_as_pdf_rounded,
                  ),
                  _StatCard(
                    title: 'Audio + Video',
                    value: stats.audioFiles + stats.videoFiles,
                    icon: Icons.perm_media_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Content Distribution',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              _DistributionCard(stats: stats),
              const SizedBox(height: 28),
              _OverviewCard(stats: stats),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _WelcomeHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Here is a quick overview of your MediData platform.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Refresh dashboard',
          child: IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.60),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
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

class _DistributionCard extends StatelessWidget {
  final AdminStats stats;

  const _DistributionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.files;
    final pdf = total == 0 ? 0.0 : stats.pdfFiles / total;
    final audio = total == 0 ? 0.0 : stats.audioFiles / total;
    final video = total == 0 ? 0.0 : stats.videoFiles / total;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  '$total total active files',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (stats.pdfFiles > 0)
                      Expanded(flex: stats.pdfFiles, child: Container(color: Colors.red.shade400)),
                    if (stats.audioFiles > 0)
                      Expanded(flex: stats.audioFiles, child: Container(color: Colors.orange.shade400)),
                    if (stats.videoFiles > 0)
                      Expanded(flex: stats.videoFiles, child: Container(color: Colors.blue.shade400)),
                    if (total == 0)
                      Expanded(child: Container(color: Theme.of(context).dividerColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _DistributionRow(
              title: 'PDF',
              value: stats.pdfFiles,
              percentage: pdf,
              icon: Icons.picture_as_pdf_rounded,
              iconColor: Colors.red.shade400,
            ),
            const SizedBox(height: 14),
            _DistributionRow(
              title: 'Audio',
              value: stats.audioFiles,
              percentage: audio,
              icon: Icons.audio_file_rounded,
              iconColor: Colors.orange.shade400,
            ),
            const SizedBox(height: 14),
            _DistributionRow(
              title: 'Video',
              value: stats.videoFiles,
              percentage: video,
              icon: Icons.video_file_rounded,
              iconColor: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String title;
  final int value;
  final double percentage;
  final IconData icon;
  final Color iconColor;

  const _DistributionRow({
    required this.title,
    required this.value,
    required this.percentage,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: Text(
            '$value  (${(percentage * 100).toStringAsFixed(1)}%)',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final AdminStats stats;

  const _OverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Lectures are counted as main lecture records, while PDF, audio and video statistics come from active lecture files. Current published lectures: ${stats.publishedLectures}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 44,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load dashboard statistics.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

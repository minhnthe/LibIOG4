import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../bloc/realtime/realtime_bloc.dart';
import '../../../../data/models/occupancy_stats_model.dart';
import '../../../../data/models/present_student_model.dart';

class LiveOccupancyTab extends StatefulWidget {
  const LiveOccupancyTab({super.key});

  @override
  State<LiveOccupancyTab> createState() => _LiveOccupancyTabState();
}

class _LiveOccupancyTabState extends State<LiveOccupancyTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<RealtimeBloc>().add(const StartAutoRefreshEvent());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getOccupancyColor(int percent) {
    if (percent >= 90) return Colors.red.shade600;
    if (percent >= 70) return Colors.orange.shade700;
    return Colors.green.shade600;
  }

  void _confirmForceCheckOut(BuildContext context, PresentStudentModel student) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade600),
            const SizedBox(width: 10),
            const Text('Xác nhận mời ra'),
          ],
        ),
        content: Text(
          'Xác nhận mời sinh viên ${student.name} (${student.studentId}) rời khỏi thư viện?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<RealtimeBloc>().add(
                    ForceCheckOutUserEvent(student.userId, student.name),
                  );
            },
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<RealtimeBloc, RealtimeState>(
      listener: (context, state) {
        if (state is RealtimeActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is RealtimeError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        OccupancyStatsModel? data;
        if (state is RealtimeLoaded) {
          data = state.data;
        } else if (state is RealtimeActionSuccess) {
          data = state.data;
        } else if (state is RealtimeError) {
          data = state.fallbackData;
        }

        if (state is RealtimeLoading && data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final current = data?.currentOccupancy ?? 0;
        final max = (data?.maxCapacity ?? 100) > 0 ? (data?.maxCapacity ?? 100) : 100;
        final percent = data?.occupancyPercent ?? ((current / max) * 100).round();
        final statusColor = _getOccupancyColor(percent);
        final isFull = current >= max;

        // Filter present student list
        final allStudents = data?.presentList ?? [];
        final filteredStudents = allStudents.where((s) {
          if (_searchQuery.isEmpty) return true;
          return s.name.toLowerCase().contains(_searchQuery) ||
              s.studentId.toLowerCase().contains(_searchQuery);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            context.read<RealtimeBloc>().add(const FetchRealtimeDataEvent());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Live Occupancy Header
                    _buildOccupancyHeaderCard(
                      theme: theme,
                      current: current,
                      max: max,
                      percent: percent,
                      statusColor: statusColor,
                      isFull: isFull,
                      totalVisitsToday: data?.totalVisitsToday ?? 0,
                      peakOccupancy: data?.peakOccupancy ?? 0,
                    ),
                    const SizedBox(height: 24),

                    // Search & Title Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sinh viên đang có mặt (${allStudents.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Làm mới ngay',
                          onPressed: () {
                            context.read<RealtimeBloc>().add(const FetchRealtimeDataEvent());
                          },
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên hoặc mã sinh viên...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Present Students List
                    if (filteredStudents.isEmpty)
                      _buildEmptyState(theme, hasFilter: _searchQuery.isNotEmpty)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _buildStudentTile(context, student, theme);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOccupancyHeaderCard({
    required ThemeData theme,
    required int current,
    required int max,
    required int percent,
    required Color statusColor,
    required bool isFull,
    required int totalVisitsToday,
    required int peakOccupancy,
  }) {
    final progressVal = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top live indicator row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade600.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRỰC TIẾP (Cập nhật mỗi 4s)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (isFull)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ĐÃ HẾT CHỖ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Text(
                    '$percent% công suất',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Number display
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$current',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
                Text(
                  ' / $max chỗ',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressVal,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 20),

            // Secondary Stats
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  theme: theme,
                  icon: Icons.login_rounded,
                  label: 'Tổng lượt vào hôm nay',
                  value: '$totalVisitsToday lượt',
                ),
                Container(width: 1, height: 35, color: Colors.grey.withValues(alpha: 0.3)),
                _buildStatItem(
                  theme: theme,
                  icon: Icons.trending_up_rounded,
                  label: 'Lượt cao điểm nhất',
                  value: '$peakOccupancy người',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStudentTile(BuildContext context, PresentStudentModel student, ThemeData theme) {
    final checkInFormatted = student.checkInTime != null
        ? DateFormat('HH:mm').format(student.checkInTime!)
        : '--:--';

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        student.studentId,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '• Vào lúc: $checkInFormatted',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${student.durationMinutes} phút',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _confirmForceCheckOut(context, student),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Mời ra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {required bool hasFilter}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            hasFilter ? Icons.search_off_rounded : Icons.airline_seat_recline_normal_rounded,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Không tìm thấy sinh viên phù hợp với từ khóa'
                : 'Thư viện hiện đang trống',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'Hãy thử kiểm tra lại MSSV hoặc họ tên'
                : 'Chưa có sinh viên nào check-in vào thư viện lúc này',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

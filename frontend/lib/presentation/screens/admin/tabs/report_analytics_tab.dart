import 'dart:io' show File;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/config/config_bloc.dart';
import '../../../bloc/report/report_bloc.dart';
import '../../../../data/models/report_data_model.dart';

class ReportAnalyticsTab extends StatefulWidget {
  const ReportAnalyticsTab({super.key});

  @override
  State<ReportAnalyticsTab> createState() => _ReportAnalyticsTabState();
}

class _ReportAnalyticsTabState extends State<ReportAnalyticsTab> {
  String _selectedFilter = 'hour'; // 'hour' | 'day' | 'week'

  @override
  void initState() {
    super.initState();
    context.read<ReportBloc>().add(FetchReportEvent(groupBy: _selectedFilter));
    context.read<ConfigBloc>().add(const LoadConfigEvent());
  }

  void _onFilterChanged(String newFilter) {
    if (_selectedFilter == newFilter) return;
    setState(() {
      _selectedFilter = newFilter;
    });
    context.read<ReportBloc>().add(FetchReportEvent(groupBy: _selectedFilter));
  }

  void _onRefresh() {
    context.read<ReportBloc>().add(FetchReportEvent(groupBy: _selectedFilter));
  }

  void _onExportCsv() {
    context.read<ReportBloc>().add(const ExportCsvEvent());
  }

  Future<void> _handleCsvDownloaded(
    BuildContext context,
    String csvContent,
    String fileName,
  ) async {
    String? localPath;
    if (!kIsWeb) {
      try {
        final file = File(fileName);
        await file.writeAsString(csvContent);
        localPath = file.absolute.path;
      } catch (_) {}
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final rowCount = lines.isEmpty ? 0 : lines.length - 1; // trừ dòng tiêu đề

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.file_download_done_rounded, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Xuất file CSV thành công!',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'File: $fileName ($rowCount lượt ghi nhận)',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (localPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 20, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đã lưu tại: $localPath',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Sao chép CSV'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csvContent));
                        Navigator.of(bottomSheetCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đã sao chép nội dung CSV vào bộ nhớ tạm'),
                            backgroundColor: Colors.blue.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      child: const Text('Đóng'),
                      onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ReportBloc, ReportState>(
      listener: (context, state) {
        if (state is ReportExportSuccess) {
          _handleCsvDownloaded(context, state.csvContent, state.fileName);
        } else if (state is ReportError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
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
        final isLoading = state is ReportLoading;
        final isExporting = (state is ReportLoaded && state.isExporting);

        ReportDataModel data = ReportDataModel.empty();
        if (state is ReportLoaded) {
          data = state.data;
        } else if (state is ReportExportSuccess) {
          data = state.data;
        } else if (state is ReportError && state.fallbackData != null) {
          data = state.fallbackData!;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: RefreshIndicator(
            onRefresh: () async => _onRefresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Thanh công cụ: Tiêu đề, Bộ lọc & Nút Xuất CSV ──
                      _buildHeaderToolbar(theme, isLoading, isExporting),
                      const SizedBox(height: 20),

                      // ── 3 Thẻ KPI tổng hợp ──
                      _buildKpiRow(theme, data),
                      const SizedBox(height: 24),

                      // ── Khối Biểu đồ Cột (fl_chart) ──
                      _buildChartCard(theme, data, isLoading),
                      const SizedBox(height: 24),

                      // ── Bảng phân bố chi tiết theo từng mốc ──
                      _buildDetailsCard(theme, data),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderToolbar(ThemeData theme, bool isLoading, bool isExporting) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            // Tiêu đề & phụ đề
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bar_chart_rounded, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống Kê Lượt Ra Vào',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Phân tích lưu lượng sinh viên sử dụng thư viện',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),

            // Bộ lọc: Theo Giờ / Theo Ngày / Theo Tuần
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'hour', label: Text('Theo Giờ')),
                    ButtonSegment(value: 'day', label: Text('Theo Ngày')),
                    ButtonSegment(value: 'week', label: Text('Theo Tuần')),
                  ],
                  selected: {_selectedFilter},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) _onFilterChanged(set.first);
                  },
                ),
                const SizedBox(width: 4),

                // Nút Làm mới
                IconButton(
                  tooltip: 'Làm mới dữ liệu',
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  onPressed: isLoading ? null : _onRefresh,
                ),

                // Nút Xuất file CSV
                FilledButton.icon(
                  icon: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Xuất CSV'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (isLoading || isExporting) ? null : _onExportCsv,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(ThemeData theme, ReportDataModel data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 32) / 3;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Tổng Lượt Vào',
                value: '${data.totalVisits}',
                unit: 'lượt khách',
                icon: Icons.groups_rounded,
                color: Colors.blue.shade700,
                backgroundColor: Colors.blue.shade50,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Thời Gian Ngồi TB',
                value: '${data.avgDuration}',
                unit: 'phút / lượt',
                icon: Icons.timer_outlined,
                color: Colors.orange.shade700,
                backgroundColor: Colors.orange.shade50,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Khung Giờ Cao Điểm',
                value: data.peakTimeLabel,
                unit: data.peakCheckIns > 0 ? '${data.peakCheckIns} lượt vào' : 'chưa có dữ liệu',
                icon: Icons.local_fire_department_rounded,
                color: Colors.red.shade700,
                backgroundColor: Colors.red.shade50,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, ReportDataModel data, bool isLoading) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biểu Đồ Phân Bố Lượt Check-in',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedFilter == 'hour'
                          ? 'Dữ liệu phân bố theo các khung giờ trong ngày'
                          : (_selectedFilter == 'day'
                              ? 'Dữ liệu phân bố theo các ngày trong tuần'
                              : 'Dữ liệu phân bố theo các tuần trong tháng'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BlocBuilder<ConfigBloc, ConfigState>(
                      builder: (context, configState) {
                        if (configState is ConfigLoaded) {
                          final cfg = configState.config;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'MAX_CAPACITY: ${cfg.maxCapacity} | OPEN: ${cfg.openTime} - ${cfg.closeTime}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: Colors.blue.shade800,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 320,
              child: data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có dữ liệu lượt ra vào trong khoảng thời gian này',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : _buildBarChart(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(ReportDataModel data) {
    final labels = data.labels;
    final checkIns = data.checkIns;
    final maxVal = data.maxCheckIns;
    final maxY = (maxVal * 1.25).ceilToDouble().clamp(5.0, double.infinity);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < labels.length; i++) {
      final value = i < checkIns.length ? checkIns[i].toDouble() : 0.0;
      final isPeak = value == maxVal && maxVal > 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              gradient: LinearGradient(
                colors: isPeak
                    ? [Colors.orange.shade700, Colors.red.shade500]
                    : [Colors.blue.shade700, Colors.blue.shade400],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: labels.length > 15 ? 12 : 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade900,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = groupIndex < labels.length ? labels[groupIndex] : '';
              return BarTooltipItem(
                '$label\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} lượt check-in',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }

                // Nếu quá nhiều mốc, hiển thị cách quãng để không bị đè chữ
                if (labels.length > 12 && index % 2 != 0) {
                  return const SizedBox.shrink();
                }

                final text = labels[index];
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble().clamp(1.0, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme, ReportDataModel data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = data.maxCheckIns;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bảng Phân Bố Chi Tiết',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.labels.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final label = data.labels[index];
                final count = index < data.checkIns.length ? data.checkIns[index] : 0;
                final ratio = maxVal > 0 ? (count / maxVal) : 0.0;
                final isPeak = count == maxVal && maxVal > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                            color: isPeak ? Colors.red.shade700 : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade100,
                            color: isPeak ? Colors.red.shade500 : Colors.blue.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '$count lượt',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPeak ? Colors.red.shade700 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

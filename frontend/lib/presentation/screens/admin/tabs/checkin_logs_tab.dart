import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../bloc/checkin_logs/checkin_logs_bloc.dart';
import '../../../../data/models/checkin_log_admin_model.dart';

class CheckinLogsTab extends StatefulWidget {
  const CheckinLogsTab({super.key});

  @override
  State<CheckinLogsTab> createState() => _CheckinLogsTabState();
}

class _CheckinLogsTabState extends State<CheckinLogsTab> {
  final _searchController = TextEditingController();
  String? _selectedStatus;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    context.read<CheckinLogsBloc>().add(const LoadCheckinLogsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadLogs() {
    context.read<CheckinLogsBloc>().add(
      LoadCheckinLogsEvent(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        status: _selectedStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckinLogsBloc, CheckinLogsState>(
      listener: (context, state) {
        if (state is CheckinLogsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final logs = state is CheckinLogsLoaded
            ? state.logs
            : state is CheckinLogsLoading
            ? state.logs
            : state is CheckinLogsError
            ? state.fallbackLogs
            : <CheckinLogAdminModel>[];
        final isLoading = state is CheckinLogsLoading && logs.isEmpty;
        final insideCount = logs.where((log) => log.isInside).length;
        final completedCount = logs.where((log) => !log.isInside).length;

        return RefreshIndicator(
          onRefresh: () async => _loadLogs(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Nhật ký check-in / check-out',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Theo dõi lịch sử ra vào của sinh viên và trạng thái phiên hiện tại.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Tổng lượt',
                      value: logs.length.toString(),
                      icon: Icons.receipt_long_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Đang ở trong',
                      value: insideCount.toString(),
                      icon: Icons.login_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Đã hoàn tất',
                      value: completedCount.toString(),
                      icon: Icons.logout_rounded,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _loadLogs(),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo MSSV hoặc họ tên',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Tìm kiếm',
                              onPressed: _loadLogs,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String?>(
                        value: _selectedStatus,
                        hint: const Text('Tất cả'),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'INSIDE',
                            child: Text('Đang ở trong'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'COMPLETED',
                            child: Text('Đã hoàn tất'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _loadLogs();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Chưa có nhật ký phù hợp')),
                )
              else
                ...logs.map(_buildLogCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogCard(CheckinLogAdminModel log) {
    final isInside = log.isInside;
    final color = isInside ? Colors.orange : Colors.green;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isInside ? Icons.login_rounded : Icons.logout_rounded,
            color: color,
          ),
        ),
        title: Text(
          log.studentName.isEmpty ? log.studentId : log.studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'MSSV: ${log.studentId}\n'
            'Vào: ${_dateFormat.format(log.checkInTime)}\n'
            'Ra: ${log.checkOutTime == null ? 'Chưa check-out' : _dateFormat.format(log.checkOutTime!)}\n'
            'Cổng: ${log.gateName}',
          ),
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(isInside ? 'ĐANG Ở TRONG' : 'HOÀN TẤT'),
          labelStyle: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

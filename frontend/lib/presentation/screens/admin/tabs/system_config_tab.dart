import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/config/config_bloc.dart';
import '../../../../data/models/system_config_model.dart';

class SystemConfigTab extends StatefulWidget {
  const SystemConfigTab({super.key});

  @override
  State<SystemConfigTab> createState() => _SystemConfigTabState();
}

class _SystemConfigTabState extends State<SystemConfigTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _capacityController;
  late TextEditingController _maintenanceMsgController;

  String _openTime = '07:00';
  String _closeTime = '21:00';
  String? _nextOpenTime;
  String? _nextCloseTime;
  String? _effectiveDate;
  bool _maintenanceMode = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _capacityController = TextEditingController();
    _maintenanceMsgController = TextEditingController();
    context.read<ConfigBloc>().add(const LoadConfigEvent());
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _maintenanceMsgController.dispose();
    super.dispose();
  }

  void _populateFromConfig(SystemConfigModel config) {
    _capacityController.text = config.maxCapacity.toString();
    _maintenanceMsgController.text = config.maintenanceMessage;
    _openTime = config.openTime;
    _closeTime = config.closeTime;
    _maintenanceMode = config.maintenanceMode;
    _nextOpenTime = config.nextOpenTime;
    _nextCloseTime = config.nextCloseTime;
    _effectiveDate = config.effectiveDate;
    _initialized = true;
  }

  Future<void> _selectTime({required bool isOpenTime}) async {
    final currentTimeStr = isOpenTime ? _openTime : _closeTime;
    final parts = currentTimeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? (isOpenTime ? 7 : 21),
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpenTime) {
          _openTime = formatted;
        } else {
          _closeTime = formatted;
        }
      });
    }
  }

  void _saveConfig() {
    if (!_formKey.currentState!.validate()) return;

    final maxCapacity = int.tryParse(_capacityController.text.trim()) ?? 100;
    final configMap = <String, dynamic>{
      'maxCapacity': maxCapacity,
      'openTime': _openTime,
      'closeTime': _closeTime,
      'maintenanceMode': _maintenanceMode,
      'maintenanceMessage': _maintenanceMsgController.text.trim(),
    };

    context.read<ConfigBloc>().add(UpdateConfigEvent(configMap));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ConfigBloc, ConfigState>(
      listener: (context, state) {
        if (state is ConfigLoaded) {
          if (!_initialized) {
            _populateFromConfig(state.config);
          }
        } else if (state is ConfigUpdateSuccess) {
          _populateFromConfig(state.config);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(state.message),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is ConfigError) {
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
        if (state is ConfigLoading && !_initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaving = state is ConfigUpdating;

        return RefreshIndicator(
          onRefresh: () async {
            _initialized = false;
            context.read<ConfigBloc>().add(const LoadConfigEvent());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                              theme.colorScheme.primary.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.settings_suggest_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cấu hình vận hành thư viện',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Các thông số sẽ có hiệu lực tức thì trên toàn hệ thống mà không cần restart máy chủ.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card 1: Sức chứa tối đa
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people_alt_rounded,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sức chứa tối đa (Max Capacity)',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Số lượng chỗ ngồi tối đa phục vụ sinh viên cùng một thời điểm.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _capacityController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Số chỗ ngồi tối đa',
                                  hintText: 'Ví dụ: 100',
                                  prefixIcon: const Icon(Icons.chair_alt_rounded),
                                  suffixText: 'chỗ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập sức chứa';
                                  }
                                  final numVal = int.tryParse(value.trim());
                                  if (numVal == null || numVal <= 0) {
                                    return 'Sức chứa phải là số nguyên dương > 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Khung giờ mở & đóng cửa
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Khung giờ hoạt động',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sinh viên chỉ có thể quét thẻ vào thư viện trong khung giờ này.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimePickerTile(
                                      context: context,
                                      label: 'Giờ mở cửa',
                                      timeString: _openTime,
                                      icon: Icons.wb_sunny_outlined,
                                      onTap: () => _selectTime(isOpenTime: true),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildTimePickerTile(
                                      context: context,
                                      label: 'Giờ đóng cửa',
                                      timeString: _closeTime,
                                      icon: Icons.nights_stay_outlined,
                                      onTap: () => _selectTime(isOpenTime: false),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Thay đổi giờ mở/đóng cửa sẽ chính thức áp dụng từ ngày hôm sau để không làm gián đoạn ca phục vụ hôm nay.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.blue.shade800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_nextOpenTime != null &&
                                  _nextCloseTime != null &&
                                  _effectiveDate != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_available_rounded,
                                          color: Colors.amber.shade900, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Đã lên lịch thay đổi khung giờ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Từ ngày $_effectiveDate, thư viện sẽ áp dụng khung giờ mới: $_nextOpenTime – $_nextCloseTime.',
                                              style: TextStyle(
                                                color: Colors.amber.shade900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 3: Chế độ bảo trì
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _maintenanceMode
                                ? Colors.orange.shade400
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.engineering_rounded,
                                    color: _maintenanceMode
                                        ? Colors.orange.shade700
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Chế độ bảo trì (Maintenance Mode)',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Khi bật, hệ thống sẽ tạm dừng cho phép sinh viên quét thẻ vào.',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _maintenanceMode,
                                    activeThumbColor: Colors.orange.shade700,
                                    onChanged: (val) {
                                      setState(() {
                                        _maintenanceMode = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (_maintenanceMode) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _maintenanceMsgController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Thông báo bảo trì hiển thị cho sinh viên',
                                    hintText: 'Thư viện tạm thời bảo trì để kiểm kê tài liệu...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Action Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : _saveConfig,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            isSaving ? 'ĐANG LƯU CẤU HÌNH...' : 'LƯU CẤU HÌNH HỆ THỐNG',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
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

  Widget _buildTimePickerTile({
    required BuildContext context,
    required String label,
    required String timeString,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeString,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/auth/auth_bloc.dart';
import '../../../bloc/gate_management/gate_management_bloc.dart';
import '../../../../data/models/gate_model.dart';

class GateManagementTab extends StatefulWidget {
  const GateManagementTab({super.key});

  @override
  State<GateManagementTab> createState() => _GateManagementTabState();
}

class _GateManagementTabState extends State<GateManagementTab> {
  @override
  void initState() {
    super.initState();
    context.read<GateManagementBloc>().add(const LoadGatesEvent());
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        (context.watch<AuthBloc>().state is Authenticated) &&
        (context.read<AuthBloc>().state as Authenticated).user.isAdmin;

    return BlocConsumer<GateManagementBloc, GateManagementState>(
      listener: (context, state) {
        if (state is GateManagementCreated) {
          _showMessage('Đã tạo cổng ${state.gate.gateName}', isError: false);
        } else if (state is GateManagementUpdated) {
          _showMessage(
            'Đã cập nhật trạng thái ${state.gate.gateName}',
            isError: false,
          );
        } else if (state is GateManagementError) {
          _showMessage(state.message, isError: true);
        }
      },
      builder: (context, state) {
        final gates = state is GateManagementLoaded
            ? state.gates
            : state is GateManagementCreated
            ? state.gates
            : state is GateManagementUpdated
            ? state.gates
            : state is GateManagementError
            ? state.fallbackGates ?? <GateModel>[]
            : <GateModel>[];
        final isLoading = state is GateManagementLoading && gates.isEmpty;
        final activeCount = gates.where((gate) => gate.isActive).length;

        return RefreshIndicator(
          onRefresh: () async =>
              context.read<GateManagementBloc>().add(const LoadGatesEvent()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.door_front_door_rounded,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quản lý cổng',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$activeCount/${gates.length} cổng đang hoạt động',
                            ),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Thêm cổng',
                          onPressed: _showCreateGateDialog,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (gates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('Chưa có cổng nào được cấu hình')),
                )
              else
                ...gates.map((gate) => _buildGateCard(gate, isAdmin)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGateCard(GateModel gate, bool isAdmin) {
    final isMaintenance = gate.status == 'MAINTENANCE';
    final color = gate.isActive
        ? Colors.green
        : isMaintenance
        ? Colors.orange
        : Colors.grey;
    final statusText = gate.isActive
        ? 'ĐANG HOẠT ĐỘNG'
        : isMaintenance
        ? 'BẢO TRÌ'
        : 'TẮT';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.door_front_door_rounded, color: color),
        ),
        title: Text(
          gate.gateName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          gate.location.isEmpty ? 'Chưa cập nhật vị trí' : gate.location,
        ),
        trailing: isAdmin
            ? DropdownButton<String>(
                value: gate.status,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Tắt')),
                  DropdownMenuItem(
                    value: 'MAINTENANCE',
                    child: Text('Bảo trì'),
                  ),
                ],
                onChanged: (status) {
                  if (status != null && status != gate.status) {
                    context.read<GateManagementBloc>().add(
                      UpdateGateStatusEvent(gateId: gate.id, status: status),
                    );
                  }
                },
              )
            : Chip(
                label: Text(statusText),
                labelStyle: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: color.withValues(alpha: 0.12),
              ),
      ),
    );
  }

  Future<void> _showCreateGateDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Thêm cổng mới'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên cổng'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên cổng'
                      : null,
                ),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí (không bắt buộc)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext);
                context.read<GateManagementBloc>().add(
                  CreateGateEvent(
                    gateName: nameController.text,
                    location: locationController.text,
                  ),
                );
              },
              child: const Text('TẠO'),
            ),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      nameController.dispose();
      locationController.dispose();
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }
}

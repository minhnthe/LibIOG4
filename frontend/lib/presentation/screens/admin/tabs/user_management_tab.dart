import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../bloc/auth/auth_bloc.dart';
import '../../../bloc/user_management/user_management_bloc.dart';
import '../../../../data/models/user_admin_model.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    context.read<UserManagementBloc>().add(const FetchUsersEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      context.read<UserManagementBloc>().add(
        FetchUsersEvent(query: query.trim(), status: _selectedStatusFilter),
      );
    });
  }

  void _onFilterSelected(String? status) {
    setState(() {
      _selectedStatusFilter = status;
    });
    context.read<UserManagementBloc>().add(
      FetchUsersEvent(
        query: _searchController.text.trim(),
        status: _selectedStatusFilter,
      ),
    );
  }

  void _confirmToggleStatus(
    UserAdminModel user, {
    required bool canToggle,
    String? disableReason,
  }) {
    if (!canToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            disableReason ?? 'Không thể thao tác trên tài khoản này',
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final willLock = user.isActive;
    final actionText = willLock ? 'Khóa thẻ' : 'Mở khóa thẻ';
    final contentText = willLock
        ? 'Bạn có chắc chắn muốn khóa thẻ của ${user.name} (${user.studentId})?\nSau khi khóa, sinh viên sẽ bị TỪ CHỐI khi quẹt thẻ vào thư viện.${user.isInsideLibrary ? '\n\nLưu ý (TC-07): Sinh viên đang có mặt trong thư viện vẫn được phép quẹt thẻ ra về bình thường.' : ''}'
        : 'Bạn có chắc chắn muốn mở khóa thẻ cho ${user.name} (${user.studentId})?';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willLock ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              color: willLock ? Colors.red.shade600 : Colors.green.shade600,
            ),
            const SizedBox(width: 10),
            Text('$actionText thư viện'),
          ],
        ),
        content: Text(contentText, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willLock
                  ? Colors.red.shade600
                  : Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<UserManagementBloc>().add(
                ToggleUserStatusEvent(
                  userId: user.id,
                  currentStatus: user.status,
                  studentName: user.name,
                ),
              );
            },
            child: Text(actionText.toUpperCase()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;
    final isCurrentAdmin = currentUser?.isAdmin == true;
    final currentUserId = currentUser?.id ?? '';
    final currentStudentId = currentUser?.studentId ?? '';

    return BlocConsumer<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is UserManagementStatusUpdated) {
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
        } else if (state is UserManagementUserCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã tạo ${state.user.isLibrarian ? 'tài khoản thủ thư' : 'tài khoản sinh viên'}',
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _showTemporaryPasswordDialog(state.user);
        } else if (state is UserManagementError) {
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
        List<UserAdminModel> users = [];
        if (state is UserManagementLoaded) {
          users = state.users;
        } else if (state is UserManagementStatusUpdated) {
          users = state.users;
        } else if (state is UserManagementUserCreated) {
          users = state.users;
        } else if (state is UserManagementError) {
          users = state.fallbackUsers ?? [];
        }
        final totalUsers = state is UserManagementLoaded
            ? state.total
            : state is UserManagementStatusUpdated
            ? state.total
            : state is UserManagementUserCreated
            ? state.total
            : users.length;

        final isLoading = state is UserManagementLoading && users.isEmpty;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<UserManagementBloc>().add(
              FetchUsersEvent(
                query: _searchController.text.trim(),
                status: _selectedStatusFilter,
              ),
            );
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
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                            theme.colorScheme.primary.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
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
                              Icons.manage_accounts_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quản lý thành viên & thẻ thư viện',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tìm kiếm theo tên/MSSV và gạt công tắc để khóa/mở thẻ tức thì.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Search Field
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm theo Mã SV, họ tên hoặc email...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips Row
                    Row(
                      children: [
                        Text(
                          'Lọc trạng thái:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: _selectedStatusFilter == null,
                          onSelected: (_) => _onFilterSelected(null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Hoạt động'),
                          selected: _selectedStatusFilter == 'active',
                          selectedColor: Colors.green.shade100,
                          onSelected: (_) => _onFilterSelected('active'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Bị khóa'),
                          selected: _selectedStatusFilter == 'locked',
                          selectedColor: Colors.red.shade100,
                          onSelected: (_) => _onFilterSelected('locked'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Total Count Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách thành viên ($totalUsers)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrentAdmin ||
                                currentUser?.isLibrarian == true)
                              FilledButton.icon(
                                onPressed: () => _showCreateUserDialog(
                                  context,
                                  isCurrentAdmin: isCurrentAdmin,
                                ),
                                icon: const Icon(
                                  Icons.person_add_alt_1,
                                  size: 18,
                                ),
                                label: const Text('Tạo tài khoản'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: () {
                                context.read<UserManagementBloc>().add(
                                  FetchUsersEvent(
                                    query: _searchController.text.trim(),
                                    status: _selectedStatusFilter,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Loading State
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    // Empty State
                    else if (users.isEmpty)
                      _buildEmptyState(
                        theme,
                        hasFilter: _searchController.text.isNotEmpty,
                      )
                    // Student Cards List
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _buildUserCard(
                            context,
                            user,
                            theme,
                            isCurrentAdmin: isCurrentAdmin,
                            currentUserId: currentUserId,
                            currentStudentId: currentStudentId,
                          );
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

  void _showTemporaryPasswordDialog(UserAdminModel user) {
    final password = user.tempPassword;
    if (!mounted || password == null || password.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo tài khoản thành công'),
        content: SelectableText(
          'Tài khoản: ${user.studentId}\n'
          'Mật khẩu tạm: $password\n\n'
          'Hãy gửi thông tin này cho người dùng và yêu cầu đổi mật khẩu sau khi đăng nhập.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ĐÃ HIỂU'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateUserDialog(
    BuildContext context, {
    required bool isCurrentAdmin,
  }) async {
    final userManagementBloc = context.read<UserManagementBloc>();
    final formKey = GlobalKey<FormState>();
    final studentIdController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    var selectedRole = 'STUDENT';

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Tạo tài khoản'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: studentIdController,
                      decoration: const InputDecoration(
                        labelText: 'Mã sinh viên / mã nhân viên',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập mã tài khoản'
                          : null,
                    ),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập họ tên'
                          : null,
                    ),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Vui lòng nhập email';
                        if (!value.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại (không bắt buộc)',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Vai trò'),
                      items: [
                        const DropdownMenuItem(
                          value: 'STUDENT',
                          child: Text('Sinh viên'),
                        ),
                        if (isCurrentAdmin)
                          const DropdownMenuItem(
                            value: 'LIBRARIAN',
                            child: Text('Thủ thư'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => selectedRole = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('HỦY'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(dialogContext).pop();
                  userManagementBloc.add(
                    CreateUserEvent(
                      studentId: studentIdController.text,
                      name: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                      role: selectedRole,
                    ),
                  );
                },
                child: const Text('TẠO'),
              ),
            ],
          ),
        ),
      );
      // Đợi animation đóng dialog hoàn tất trước khi hủy controller của TextField.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      studentIdController.dispose();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  Widget _buildUserCard(
    BuildContext context,
    UserAdminModel user,
    ThemeData theme, {
    required bool isCurrentAdmin,
    required String currentUserId,
    required String currentStudentId,
  }) {
    final expiryFormatted = user.cardExpiry != null
        ? DateFormat('dd/MM/yyyy').format(user.cardExpiry!)
        : 'Vô thời hạn';

    final isSelf =
        (currentUserId.isNotEmpty && user.id == currentUserId) ||
        (currentStudentId.isNotEmpty && user.studentId == currentStudentId);
    final canToggle = !isSelf && (isCurrentAdmin || user.isStudent);

    String? disableReason;
    if (isSelf) {
      disableReason = 'Không thể tự khóa tài khoản của chính mình';
    } else if (!isCurrentAdmin && !user.isStudent) {
      disableReason = 'Thủ thư chỉ có quyền quản lý thẻ sinh viên, không thể khóa tài khoản cán bộ';
    }

    Color roleBg = Colors.grey.shade100;
    Color roleText = Colors.grey.shade700;
    String roleLabel = 'SV';
    if (user.isAdmin) {
      roleBg = Colors.purple.shade50;
      roleText = Colors.purple.shade800;
      roleLabel = 'ADMIN';
    } else if (user.isLibrarian) {
      roleBg = Colors.blue.shade50;
      roleText = Colors.blue.shade800;
      roleLabel = 'THỦ THƯ';
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: user.isLocked
              ? Colors.red.shade300
              : Colors.grey.withValues(alpha: 0.2),
          width: user.isLocked ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isLocked
                  ? Colors.red.shade100
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: user.isLocked
                      ? Colors.red.shade700
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: roleText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: user.isActive
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          user.isActive ? 'HOẠT ĐỘNG' : 'BỊ KHÓA',
                          style: TextStyle(
                            color: user.isActive
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (user.isInsideLibrary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Trong TV',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        user.studentId,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${user.email}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hạn thẻ: $expiryFormatted',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Toggle Switch
            Column(
              children: [
                Switch(
                  value: user.isActive,
                  activeThumbColor: Colors.green.shade600,
                  inactiveThumbColor: Colors.red.shade600,
                  inactiveTrackColor: Colors.red.shade100,
                  onChanged: canToggle
                      ? (_) => _confirmToggleStatus(
                          user,
                          canToggle: canToggle,
                          disableReason: disableReason,
                        )
                      : null,
                ),
                Text(
                  !canToggle
                      ? (isSelf ? 'Chính bạn' : 'Cán bộ')
                      : (user.isActive ? 'Khóa' : 'Mở'),
                  style: TextStyle(
                    fontSize: 11,
                    color: !canToggle
                        ? Colors.grey.shade500
                        : (user.isActive
                              ? Colors.grey.shade600
                              : Colors.red.shade700),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, {required bool hasFilter}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            hasFilter
                ? Icons.person_search_rounded
                : Icons.people_outline_rounded,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Không tìm thấy thành viên nào phù hợp'
                : 'Chưa có thành viên nào trong danh sách',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'Hãy thử kiểm tra lại từ khóa tìm kiếm hoặc bộ lọc'
                : 'Hệ thống chưa có người dùng nào được tạo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

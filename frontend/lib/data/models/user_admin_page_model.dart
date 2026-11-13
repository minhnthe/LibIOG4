import 'user_admin_model.dart';

class UserAdminPageModel {
  final List<UserAdminModel> users;
  final int total;

  const UserAdminPageModel({
    required this.users,
    required this.total,
  });
}

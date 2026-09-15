class UserRole { static const String farmer = 'farmer'; static const String agent = 'agent'; static const String admin = 'admin'; }

class AppUser {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? avatarUrl;
  final String? agentId; // ID đại lý liên kết (nếu là nông dân)

  const AppUser({required this.id, required this.name, required this.phone, this.email, required this.role, this.avatarUrl, this.agentId});
}

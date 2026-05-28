class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final int? userId;
  final String? username;
  final String? suc;
  final int? roleId;
  final bool mustChangePassword;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.userId,
    required this.username,
    required this.suc,
    required this.roleId,
    required this.mustChangePassword,
  });

  factory AuthState.initial() => const AuthState(
        isLoading: true,
        isAuthenticated: false,
        userId: null,
        username: null,
        suc: null,
        roleId: null,
        mustChangePassword: false,
      );

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    int? userId,
    String? username,
    String? suc,
    int? roleId,
    bool? mustChangePassword,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        suc: suc ?? this.suc,
        roleId: roleId ?? this.roleId,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );
}

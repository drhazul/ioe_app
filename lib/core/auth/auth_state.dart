class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final int? userId;
  final String? username;
  final int? roleId;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.userId,
    required this.username,
    required this.roleId,
  });

  factory AuthState.initial() => const AuthState(
        isLoading: true,
        isAuthenticated: false,
        userId: null,
        username: null,
        roleId: null,
      );

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    int? userId,
    String? username,
    int? roleId,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        roleId: roleId ?? this.roleId,
      );
}

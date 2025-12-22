class AuthState {
  final bool isLoading;
  final bool isAuthenticated;

  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
  });

  factory AuthState.initial() => const AuthState(isLoading: true, isAuthenticated: false);

  AuthState copyWith({bool? isLoading, bool? isAuthenticated}) => AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

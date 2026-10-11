import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/auth/auth_controller.dart';

const _ink = AppColors.ink;
const _mutedInk = AppColors.muted;
const _brand = AppColors.navy;
const _background = AppColors.canvas;

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _loading = false;
  bool _obscurePass = true;
  int _passwordEditorVersion = 0;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    // Close the web text-input connection before sending credentials.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    var failed = false;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(username: _userCtrl.text.trim(), password: _passCtrl.text);
    } catch (e) {
      failed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_errorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        if (failed) {
          _passCtrl.value = const TextEditingValue(
            selection: TextSelection.collapsed(offset: 0),
          );
        }
        setState(() {
          _loading = false;
          if (failed) _passwordEditorVersion++;
        });
        if (failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _passwordFocusNode.requestFocus();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 880;

          return Stack(
            children: [
              const _BackgroundShapes(),
              if (isWide)
                SafeArea(child: _DesktopLayout(child: _buildFormCard()))
              else
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _MobileLayout(child: _buildFormCard()),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5ECF1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160B2333),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Bienvenido de nuevo',
              style: TextStyle(
                color: _ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa tus datos para continuar a IOE.',
              style: TextStyle(color: _mutedInk, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 28),
            _buildUserField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _brand.withValues(alpha: 0.52),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _loading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Iniciar sesión', key: ValueKey('label')),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 15, color: _mutedInk),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Acceso seguro para usuarios autorizados',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserField() {
    return TextField(
      controller: _userCtrl,
      autofillHints: const [AutofillHints.username],
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: _inputDecoration(
        label: 'Usuario',
        hint: 'Escribe tu usuario',
        icon: Icons.person_outline,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      // A failed attempt must create a fresh EditableText/web input client.
      key: ValueKey(_passwordEditorVersion),
      controller: _passCtrl,
      focusNode: _passwordFocusNode,
      autofillHints: const [AutofillHints.password],
      obscureText: _obscurePass,
      autocorrect: false,
      enableSuggestions: false,
      decoration:
          _inputDecoration(
            label: 'Contraseña',
            hint: 'Escribe tu contraseña',
            icon: Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePass
                  ? 'Mostrar contraseña'
                  : 'Ocultar contraseña',
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              color: _mutedInk,
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (_loading) return;
        _submit();
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _mutedInk, size: 21),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(
        color: _mutedInk,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.7),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  String _errorMessage(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.replaceFirst('Exception: ', '');
    }
    return text;
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(child: _WelcomePanel()),
        Expanded(
          child: ColoredBox(
            color: _background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minContentHeight = constraints.maxHeight > 64
                    ? constraints.maxHeight - 64
                    : 0.0;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/ioe_login_hero.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        semanticLabel: 'Lente óptico IOE Image Optical Experts',
      ),
    );
  }
}

class _BackgroundShapes extends StatelessWidget {
  const _BackgroundShapes();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -70,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                color: AppColors.canvasAlt,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -100,
            child: Container(
              width: 390,
              height: 390,
              decoration: BoxDecoration(
                color: AppColors.silver.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            username: _userCtrl.text.trim(),
            password: _passCtrl.text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('IOE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (_loading) return;
                    _submit();
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const CircularProgressIndicator() : const Text('Entrar'),
                  ),
                ),
              ]),
            ),
          ),
        ),
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

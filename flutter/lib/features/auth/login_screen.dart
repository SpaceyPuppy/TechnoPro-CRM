import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/prism_page.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _showServer = false;
  bool _testingServer = false;
  String? _serverTestResult;
  bool _serverTestOk = false;

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = ref.read(serverUrlProvider);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final url = normalizeServerUrl(_serverCtrl.text);
    if (url.isEmpty) return;
    _serverCtrl.text = url;
    ref.read(serverUrlProvider.notifier).state = url;
    await ref.read(authStorageProvider).saveServerUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server URL saved')),
    );
  }

  Future<void> _testServerUrl() async {
    final url = normalizeServerUrl(_serverCtrl.text);
    if (url.isEmpty) return;
    _serverCtrl.text = url;
    setState(() {
      _testingServer = true;
      _serverTestResult = null;
    });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final res = await dio.get<Map<String, dynamic>>('$url/health');
      final ok = res.data?['status'] == 'ok';
      if (!mounted) return;
      setState(() {
        _serverTestOk = ok;
        _serverTestResult = ok ? 'Connected ✓' : 'Unexpected response';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverTestOk = false;
        _serverTestResult = 'Cannot reach server';
      });
    } finally {
      if (mounted) setState(() => _testingServer = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Apply server URL if changed
    final serverUrl = normalizeServerUrl(_serverCtrl.text);
    if (serverUrl.isNotEmpty && serverUrl != ref.read(serverUrlProvider)) {
      _serverCtrl.text = serverUrl;
      ref.read(serverUrlProvider.notifier).state = serverUrl;
      await ref.read(authStorageProvider).saveServerUrl(serverUrl);
    }

    await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: PrismBackdrop(
        compact: true,
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: PrismSurface(
              radius: 32,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'TechnoPro CRM',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password is required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (authState.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      authState.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setState(() {
                      _showServer = !_showServer;
                      _serverTestResult = null;
                    }),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showServer ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Server',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_showServer) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        prefixIcon: Icon(Icons.dns_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'https://crm.example.com',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _testingServer
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_find_outlined, size: 16),
                            label: const Text('Test'),
                            onPressed: _testingServer ? null : _testServerUrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _saveServerUrl,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    if (_serverTestResult != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _serverTestResult!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _serverTestOk ? Colors.green : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

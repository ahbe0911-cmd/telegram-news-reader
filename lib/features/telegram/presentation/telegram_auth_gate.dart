import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/telegram_tdlib_service.dart';
import '../telegram_providers.dart';

class TelegramAuthGate extends ConsumerStatefulWidget {
  const TelegramAuthGate({super.key});

  @override
  ConsumerState<TelegramAuthGate> createState() => _TelegramAuthGateState();
}

class _TelegramAuthGateState extends ConsumerState<TelegramAuthGate> {
  late final TelegramTdlibService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(telegramTdlibServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TelegramAuthStatus>(
      stream: _service.statusStream,
      initialData: _service.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? _service.status;

        switch (status.stage) {
          case TelegramAuthStage.ready:
            return const _AuthenticatedHome();
          case TelegramAuthStage.needsApiCredentials:
            return _ApiCredentialsPage(
              service: _service,
              initialError: status.message,
            );
          case TelegramAuthStage.waitingForPhone:
            return _AuthenticationInputPage(
              service: _service,
              title: 'ورود به تلگرام',
              description: 'شماره موبایل را با کد کشور وارد کن.',
              label: 'شماره موبایل',
              hint: '+989121234567',
              buttonText: 'دریافت کد ورود',
              keyboardType: TextInputType.phone,
              onSubmit: _service.submitPhoneNumber,
            );
          case TelegramAuthStage.waitingForCode:
            return _AuthenticationInputPage(
              service: _service,
              title: 'تأیید شماره موبایل',
              description: 'کد ورود ارسال‌شده از طرف تلگرام را وارد کن.',
              label: 'کد تأیید',
              hint: 'کد دریافتی',
              buttonText: 'تأیید و ادامه',
              keyboardType: TextInputType.number,
              onSubmit: _service.submitCode,
            );
          case TelegramAuthStage.waitingForPassword:
            return _AuthenticationInputPage(
              service: _service,
              title: 'رمز دومرحله‌ای',
              description: 'رمز دومرحله‌ای حساب تلگرام را وارد کن.',
              label: 'رمز عبور',
              hint: 'رمز دومرحله‌ای تلگرام',
              buttonText: 'ورود به حساب',
              obscureText: true,
              onSubmit: _service.submitPassword,
            );
          case TelegramAuthStage.waitingForEmailAddress:
            return _AuthenticationInputPage(
              service: _service,
              title: 'تأیید ایمیل',
              description: 'ایمیل درخواستی تلگرام را وارد کن.',
              label: 'ایمیل',
              hint: 'name@example.com',
              buttonText: 'ادامه',
              keyboardType: TextInputType.emailAddress,
              onSubmit: _service.submitEmailAddress,
            );
          case TelegramAuthStage.waitingForEmailCode:
            return _AuthenticationInputPage(
              service: _service,
              title: 'کد تأیید ایمیل',
              description: 'کدی را که تلگرام به ایمیل فرستاده وارد کن.',
              label: 'کد ایمیل',
              hint: 'کد دریافتی',
              buttonText: 'تأیید',
              keyboardType: TextInputType.number,
              onSubmit: _service.submitEmailCode,
            );
          case TelegramAuthStage.error:
            return _ConnectionMessagePage(
              title: 'اتصال تلگرام برقرار نشد',
              message: status.message ?? 'یک خطای نامشخص رخ داده است.',
              primaryLabel: 'تلاش دوباره',
              onPrimary: _service.retry,
              secondaryLabel: 'ویرایش API ID و Hash',
              onSecondary: _service.clearApiCredentials,
            );
          case TelegramAuthStage.closed:
            return _ConnectionMessagePage(
              title: 'نشست تلگرام بسته شد',
              message: 'برای اتصال دوباره، تلاش مجدد را انتخاب کن.',
              primaryLabel: 'اتصال دوباره',
              onPrimary: _service.retry,
            );
          case TelegramAuthStage.checking:
          case TelegramAuthStage.initializing:
          case TelegramAuthStage.waitingForOtherDeviceConfirmation:
            return _ConnectingPage(message: status.message);
        }
      },
    );
  }
}

class _ApiCredentialsPage extends StatefulWidget {
  const _ApiCredentialsPage({
    required this.service,
    this.initialError,
  });

  final TelegramTdlibService service;
  final String? initialError;

  @override
  State<_ApiCredentialsPage> createState() => _ApiCredentialsPageState();
}

class _ApiCredentialsPageState extends State<_ApiCredentialsPage> {
  final _apiIdController = TextEditingController();
  final _apiHashController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiId = int.tryParse(_apiIdController.text.trim());
    if (apiId == null) {
      setState(() => _error = 'API ID باید فقط شامل عدد باشد.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.saveApiCredentials(
        apiId: apiId,
        apiHash: _apiHashController.text,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'اتصال مستقیم به تلگرام',
      subtitle: 'برای راه‌اندازی اتصال امن، API ID و API Hash خودت را وارد کن.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _apiIdController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'API ID',
              hintText: '12345678',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _apiHashController,
            obscureText: true,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'API Hash',
              hintText: 'کد ۳۲ کاراکتری',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'این دو مقدار را از my.telegram.org دریافت می‌کنی. اطلاعات در حافظه امن گوشی ذخیره می‌شوند و به مخزن GitHub یا سرور برنامه ارسال نمی‌شوند.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://my.telegram.org'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('رفتن به my.telegram.org'),
            ),
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('ذخیره و اتصال'),
          ),
        ],
      ),
    );
  }
}

class _AuthenticationInputPage extends StatefulWidget {
  const _AuthenticationInputPage({
    required this.service,
    required this.title,
    required this.description,
    required this.label,
    required this.hint,
    required this.buttonText,
    required this.onSubmit,
    this.keyboardType,
    this.obscureText = false,
  });

  final TelegramTdlibService service;
  final String title;
  final String description;
  final String label;
  final String hint;
  final String buttonText;
  final Future<void> Function(String) onSubmit;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  State<_AuthenticationInputPage> createState() =>
      _AuthenticationInputPageState();
}

class _AuthenticationInputPageState extends State<_AuthenticationInputPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_controller.text);
      _controller.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: widget.title,
      subtitle: widget.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorText(_error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.buttonText),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: colors.primaryContainer,
                        child: Icon(
                          Icons.telegram,
                          size: 38,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.7,
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _ConnectingPage extends StatelessWidget {
  const _ConnectingPage({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'در حال اتصال امن به تلگرام…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionMessagePage extends StatelessWidget {
  const _ConnectionMessagePage({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: title,
      subtitle: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// Imported lazily through the auth gate to avoid changing the feed shell.
class _AuthenticatedHome extends StatelessWidget {
  const _AuthenticatedHome();

  @override
  Widget build(BuildContext context) {
    return const _MainShellLoader();
  }
}

class _MainShellLoader extends StatelessWidget {
  const _MainShellLoader();

  @override
  Widget build(BuildContext context) {
    return const _TelegramMainShellPlaceholder();
  }
}

class _TelegramMainShellPlaceholder extends StatelessWidget {
  const _TelegramMainShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('اتصال تلگرام برقرار شد. در حال آماده‌سازی خبرها…'),
      ),
    );
  }
}

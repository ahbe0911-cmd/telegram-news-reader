import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The default destination for all article links. External browsing happens
/// only when the user explicitly selects "Open in browser".
class InAppBrowserPage extends StatefulWidget {
  const InAppBrowserPage({required this.initialUrl, super.key});
  final String initialUrl;

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String _title = 'مرورگر داخلی';
  String _currentUrl = '';
  String? _mainError;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.initialUrl);
    _currentUrl = widget.initialUrl;
    if (uri != null && _isWebUri(uri)) _title = uri.host;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          setState(() {
            _currentUrl = url;
            _title = Uri.tryParse(url)?.host ?? 'مرورگر داخلی';
            _mainError = null;
            _progress = 0;
          });
          _syncNavigation();
        },
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onPageFinished: (url) {
          if (!mounted) return;
          _updateTitle(url);
          _syncNavigation();
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _mainError = error.description);
          }
        },
        onNavigationRequest: (request) {
          final target = Uri.tryParse(request.url);
          return target != null && _isWebUri(target)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));

    if (uri == null || !_isWebUri(uri)) {
      _mainError = 'آدرس صفحه معتبر نیست.';
    } else {
      _controller.loadRequest(uri);
    }
  }

  bool _isWebUri(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

  Future<void> _updateTitle(String url) async {
    final title = await _controller.getTitle();
    if (!mounted) return;
    setState(() {
      _currentUrl = url;
      if (title != null && title.trim().isNotEmpty) {
        _title = title.trim();
      }
    });
  }

  Future<void> _syncNavigation() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _syncNavigation();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
      await _syncNavigation();
    }
  }

  Future<void> _reload() async {
    setState(() => _mainError = null);
    await _controller.reload();
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null || !_isWebUri(uri)) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('امکان باز کردن مرورگر دستگاه وجود ندارد.')),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مرورگر دستگاه باز نشد: ${error.message ?? ''}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoBack) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                Uri.tryParse(_currentUrl)?.host ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'بازگشت در وب',
              onPressed: _canGoBack ? _goBack : null,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            IconButton(
              tooltip: 'صفحه بعد',
              onPressed: _canGoForward ? _goForward : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded),
            ),
            IconButton(
              tooltip: 'بازخوانی صفحه',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'گزینه‌های مرورگر',
              onSelected: (value) {
                if (value == 'external') _openExternally();
                if (value == 'copy') {
                  Clipboard.setData(ClipboardData(text: _currentUrl));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'copy', child: Text('کپی آدرس')),
                PopupMenuItem(
                  value: 'external',
                  child: Text('باز کردن در مرورگر دستگاه'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_progress < 100 && _mainError == null)
              LinearProgressIndicator(
                minHeight: 2,
                value: _progress <= 0 ? null : _progress / 100,
              ),
            Expanded(
              child: _mainError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 44),
                            const SizedBox(height: 12),
                            Text(_mainError!, textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('تلاش دوباره'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

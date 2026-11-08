import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InAppBrowserPage extends StatefulWidget {
  const InAppBrowserPage({required this.initialUrl, super.key});
  final String initialUrl;
  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.initialUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _error = error.description);
          }
        },
        onNavigationRequest: (request) {
          final next = Uri.tryParse(request.url);
          return next != null && (next.scheme == 'https' || next.scheme == 'http')
              ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
      ));
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _error = 'نشانی وب معتبر نیست.';
    } else {
      _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.initialUrl);
    return Scaffold(
      appBar: AppBar(
        title: Text(uri?.host ?? 'مرورگر داخلی', maxLines: 1,
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'بارگذاری دوباره',
            onPressed: () { setState(() => _error = null); _controller.reload(); },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(children: [
        if (_progress < 100 && _error == null)
          LinearProgressIndicator(value: _progress / 100),
        Expanded(child: _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('نمایش صفحه ممکن نیست:\n$_error', textAlign: TextAlign.center),
              ))
            : WebViewWidget(controller: _controller)),
      ]),
    );
  }
}

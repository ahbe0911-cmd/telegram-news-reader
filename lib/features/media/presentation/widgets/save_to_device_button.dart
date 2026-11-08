import 'package:flutter/material.dart';
import '../../data/device_save_service.dart';

/// Add to any full-screen viewer's top bar.
class SaveToDeviceButton extends StatefulWidget {
  const SaveToDeviceButton({
    this.localPath,
    this.url,
    this.fileName,
    this.mimeType,
    this.foregroundColor,
    super.key,
  });
  final String? localPath;
  final String? url;
  final String? fileName;
  final String? mimeType;
  final Color? foregroundColor;

  @override
  State<SaveToDeviceButton> createState() => _SaveToDeviceButtonState();
}

class _SaveToDeviceButtonState extends State<SaveToDeviceButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await DeviceSaveService.save(
        localPath: widget.localPath,
        url: widget.url,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل در حافظه دستگاه ذخیره شد.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ذخیره فایل ناموفق بود: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _saving
      ? const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : IconButton(
          tooltip: 'ذخیره در گالری یا دانلودها',
          onPressed: _save,
          icon: Icon(Icons.download_rounded, color: widget.foregroundColor),
        );
}

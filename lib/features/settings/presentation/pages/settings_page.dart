import 'package:flutter/material.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
          children: [
            Text('نمایش و مطالعه', style: AppTypography.ui.copyWith(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppPalette.primary,
            )),
            const SizedBox(height: 10),
            Card(child: Column(children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.view_agenda_outlined, color: AppPalette.primary),
                title: const Text('کارت‌های جمع‌وجور'),
                subtitle: const Text('فاصله کمتر بین خبرها'),
                value: settings.compactCards,
                onChanged: settings.setCompact,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.photo_outlined, color: AppPalette.primary),
                title: const Text('نمایش تصاویر خبر'),
                value: settings.showImages, onChanged: settings.setImages,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.data_saver_on_outlined, color: AppPalette.primary),
                title: const Text('صرفه‌جویی در مصرف اینترنت'),
                subtitle: const Text('دانلود خودکار تصویرهای تلگرام غیرفعال شود'),
                value: settings.dataSaver, onChanged: settings.setDataSaver,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.text_fields_rounded, color: AppPalette.primary),
                title: const Text('اندازه متن خبر'),
                subtitle: Slider(
                  value: settings.newsTextScale,
                  min: 0.85, max: 1.35, divisions: 10,
                  onChanged: (value) { settings.setTextScale(value); },
                ),
                trailing: Text('${(settings.newsTextScale * 100).round()}٪'),
              ),
            ])),
            const SizedBox(height: 18),
            Text('برنامه', style: AppTypography.ui.copyWith(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppPalette.primary,
            )),
            const SizedBox(height: 10),
            Card(child: Column(children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('خبرخوان تلگرام'),
                subtitle: Text('نسخه ۱.۴.۰؛ اتصال مستقیم به تلگرام'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('بازنشانی تنظیمات نمایش'),
                subtitle: const Text('حساب تلگرام و کانال‌ها بدون تغییر می‌مانند'),
                onTap: () async {
                  await settings.reset();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تنظیمات نمایش بازنشانی شد.')),
                    );
                  }
                },
              ),
            ])),
          ],
        ),
      ),
    );
  }
}

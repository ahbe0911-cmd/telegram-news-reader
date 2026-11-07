import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../telegram/telegram_providers.dart';
import '../../domain/entities/telegram_channel.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(telegramChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کانال‌های من'),
        actions: [
          IconButton(
            tooltip: 'همگام‌سازی کانال‌های حساب تلگرام',
            onPressed: () => _syncAccountChannels(context, ref),
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'افزودن کانال عمومی',
            onPressed: () => _showAddChannelDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChannelDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('افزودن کانال'),
      ),
      body: channels.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyChannels();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final channel = items[index];
              return _ChannelTile(
                channel: channel,
                onChanged: (enabled) async {
                  try {
                    final repository =
                        await ref.read(channelRepositoryProvider.future);
                    await repository.setEnabled(
                      username: channel.username,
                      enabled: enabled,
                    );
                    ref.invalidate(feedPageProvider());
                  } catch (error) {
                    if (!context.mounted) return;
                    _showMessage(context, 'تغییر وضعیت انجام نشد: $error');
                  }
                },
                onDelete: () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('حذف کانال'),
                      content: Text(
                        'کانال «${channel.title}» از فهرست حذف شود؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('انصراف'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete != true) return;

                  try {
                    final repository =
                        await ref.read(channelRepositoryProvider.future);
                    await repository.remove(channel.username);
                    ref.invalidate(feedPageProvider());
                  } catch (error) {
                    if (!context.mounted) return;
                    _showMessage(context, 'حذف کانال انجام نشد: $error');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('دریافت کانال‌ها ناموفق بود: $error'),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddChannelDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final usernameController = TextEditingController();
    final titleController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('افزودن کانال عمومی'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'channel_username',
                  labelText: 'آیدی کانال',
                  prefixText: '@',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'نام نمایشی (اختیاری)',
                  hintText: 'مثلاً اخبار فناوری',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final resolved = await ref
                      .read(telegramTdlibServiceProvider)
                      .resolvePublicChannel(usernameController.text);
                  final resolvedId = (resolved['id'] as num?)?.toInt();
                  if (resolvedId == null) {
                    throw StateError('تلگرام برای این آیدی کانالی پیدا نکرد.');
                  }
                  final resolvedUsername = _publicUsername(resolved) ??
                      usernameController.text.trim().replaceFirst(
                            RegExp(r'^@'),
                            '',
                          );
                  final resolvedTitle = titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : resolved['title']?.toString();
                  final channel = TelegramChannel(
                    username: resolvedUsername,
                    title: resolvedTitle,
                    chatId: resolvedId,
                  );
                  final repository =
                      await ref.read(channelRepositoryProvider.future);
                  await repository.upsert(channel);
                  ref.invalidate(feedPageProvider());

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    _showMessage(context, 'کانال اضافه شد.');
                  }
                } catch (error) {
                  setDialogState(() {
                    errorText = error is ArgumentError
                        ? 'آیدی کانال باید بین ۵ تا ۳۲ حرف، عدد یا زیرخط باشد.'
                        : 'کانال پیدا نشد یا دسترسی به آن ممکن نیست: $error';
                  });
                }
              },
              child: const Text('ذخیره کانال'),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    titleController.dispose();
  }

  String? _publicUsername(Map<String, dynamic> chat) {
    final direct = chat['username']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final usernames = chat['usernames'];
    if (usernames is Map) {
      final active = usernames['active_usernames'];
      if (active is List && active.isNotEmpty) {
        return active.first.toString();
      }
    }
    return null;
  }

  Future<void> _syncAccountChannels(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final service = ref.read(telegramTdlibServiceProvider);
      final response = await service.getChats(limit: 200);
      final ids = response['chat_ids'];
      if (ids is! List) {
        throw StateError('فهرست گفتگوهای تلگرام دریافت نشد.');
      }

      final repository = await ref.read(channelRepositoryProvider.future);
      var added = 0;

      for (final rawId in ids) {
        if (rawId is! num) continue;
        final chat = await service.getChat(rawId.toInt());
        final type = chat['type'];
        if (type is! Map ||
            type['@type'] != 'chatTypeSupergroup' ||
            type['is_channel'] != true) {
          continue;
        }

        final chatId = (chat['id'] as num?)?.toInt();
        if (chatId == null) continue;

        final username = _publicUsername(chat) ?? 'chat_${chatId.abs()}';
        final title = chat['title']?.toString() ?? 'کانال تلگرام';
        await repository.upsert(TelegramChannel(
          username: username,
          title: title,
          chatId: chatId,
        ));
        added++;
      }

      ref.invalidate(feedPageProvider());
      if (!context.mounted) return;
      _showMessage(
        context,
        added == 0
            ? 'کانال قابل‌دسترسی در فهرست گفتگوها پیدا نشد.'
            : '$added کانال از حساب تلگرام همگام‌سازی شد.',
      );
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'همگام‌سازی کانال‌ها ناموفق بود: $error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.onChanged,
    required this.onDelete,
  });

  final TelegramChannel channel;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Icon(
            Icons.campaign_rounded,
            color: colors.onSecondaryContainer,
          ),
        ),
        title: Text(
          channel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '@${channel.username}',
          textDirection: TextDirection.ltr,
        ),
        trailing: SizedBox(
          width: 108,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Switch(
                value: channel.enabled,
                onChanged: onChanged,
              ),
              IconButton(
                tooltip: 'حذف کانال',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                Icons.campaign_outlined,
                size: 32,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'فهرست کانال‌ها خالی است',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'آیدی یک کانال عمومی تلگرام را اضافه کن تا پست‌های آن اینجا نمایش داده شوند.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.7,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

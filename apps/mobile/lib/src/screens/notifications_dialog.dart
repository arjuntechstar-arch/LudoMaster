import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class NotificationsDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onRefreshHome;

  const NotificationsDialog({
    super.key,
    required this.apiClient,
    required this.onRefreshHome,
  });

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  List<NotificationItemModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifs = await widget.apiClient.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markRead(NotificationItemModel item) async {
    if (!item.isRead) {
      await widget.apiClient.markNotificationRead(item.id);
      _loadNotifications();
      widget.onRefreshHome();
    }
  }

  Future<void> _markAllRead() async {
    await widget.apiClient.markAllNotificationsRead();
    _loadNotifications();
    widget.onRefreshHome();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceElevated),
      ),
      child: Container(
        width: 480,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'NOTIFICATIONS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _notifications.any((n) => !n.isRead) ? _markAllRead : null,
                  child: Text(
                    'MARK ALL AS READ',
                    style: TextStyle(
                      color: _notifications.any((n) => !n.isRead) ? AppColors.green : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.surfaceElevated, height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.red)))
                      : _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No notifications yet',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _notifications.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                return InkWell(
                                  onTap: () => _markRead(n),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: n.isRead ? AppColors.surfaceElevated.withValues(alpha: 0.5) : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: n.isRead ? AppColors.surfaceElevated : AppColors.gold.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(n.category).withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(n.category),
                                            color: _getCategoryColor(n.category),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      n.title,
                                                      style: TextStyle(
                                                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                                        color: AppColors.textPrimary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!n.isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: const BoxDecoration(
                                                        color: AppColors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                n.body,
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'REWARD':
        return AppColors.green;
      case 'TOURNAMENT':
        return AppColors.gold;
      case 'INVITE':
        return AppColors.blue;
      default:
        return AppColors.purple;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'REWARD':
        return Icons.card_giftcard;
      case 'TOURNAMENT':
        return Icons.emoji_events;
      case 'INVITE':
        return Icons.group_add;
      default:
        return Icons.campaign;
    }
  }
}

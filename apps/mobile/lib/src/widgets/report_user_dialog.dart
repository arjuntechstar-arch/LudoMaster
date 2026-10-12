import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class ReportUserDialog extends StatefulWidget {
  final ApiClient apiClient;
  final String reportedUserId;
  final String reportedDisplayName;
  final String? matchId;

  const ReportUserDialog({
    super.key,
    required this.apiClient,
    required this.reportedUserId,
    required this.reportedDisplayName,
    this.matchId,
  });

  static Future<void> show(
    BuildContext context, {
    required ApiClient apiClient,
    required String reportedUserId,
    required String reportedDisplayName,
    String? matchId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ReportUserDialog(
        apiClient: apiClient,
        reportedUserId: reportedUserId,
        reportedDisplayName: reportedDisplayName,
        matchId: matchId,
      ),
    );
  }

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  String _category = 'HARASSMENT';
  final TextEditingController _descController = TextEditingController();
  bool _alsoBlock = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'value': 'HARASSMENT', 'label': 'Verbal Abuse / Harassment'},
    {'value': 'CHEATING', 'label': 'Suspected Cheating / Exploit'},
    {'value': 'INAPPROPRIATE_NAME', 'label': 'Offensive Name or Avatar'},
    {'value': 'SPAM', 'label': 'Chat Spamming'},
    {'value': 'OTHER', 'label': 'Other Violation'},
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.submitReport(
        reportedUserId: widget.reportedUserId,
        category: _category,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        matchId: widget.matchId,
      );

      if (_alsoBlock) {
        await widget.apiClient.blockUser(
          widget.reportedUserId,
          reason: 'Reported for $_category',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted against ${widget.reportedDisplayName}. Thank you for keeping LudoMaster safe!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report ${widget.reportedDisplayName}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select violation category:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ..._categories.map((c) {
              final isSelected = _category == c['value'];
              return InkWell(
                onTap: () => setState(() => _category = c['value']!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.gold : AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        c['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _alsoBlock,
              onChanged: (v) => setState(() => _alsoBlock = v ?? true),
              activeColor: AppColors.red,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Also block this player (mutes chat & prevents matching)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}

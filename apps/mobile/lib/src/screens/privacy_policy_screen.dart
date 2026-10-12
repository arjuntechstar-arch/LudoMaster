import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';

import '../theme/app_colors.dart';

/// The same policy text as the public store-listing page, available offline.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late Future<Map<String, dynamic>> _policy;
  @override
  void initState() {
    super.initState();
    _policy = _load();
  }

  Future<Map<String, dynamic>> _load() async => jsonDecode(
    await rootBundle.loadString('assets/legal/privacy_policy.json'),
  ) as Map<String, dynamic>;

  Widget _link(String label, String url) => Link(
    uri: Uri.parse(url),
    target: LinkTarget.blank,
    builder: (context, followLink) => TextButton.icon(
      onPressed: followLink,
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _policy,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load the privacy policy.'),
                TextButton(
                  onPressed: () => setState(() => _policy = _load()),
                  child: const Text('RETRY'),
                ),
                _link(
                  'Read the public policy',
                  'https://api-ludo.freefiremobile.space/privacy-policy',
                ),
              ],
            ),
          );
        }
        final policy = snapshot.data;
        if (policy == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final sections = (policy['sections'] as List)
            .cast<Map<String, dynamic>>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Ludo Play',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Updated ${policy['updated']} · ${policy['package_name']}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _link('Read on the website', policy['policy_url'] as String),
                for (final section in sections) ...[
                  const SizedBox(height: 24),
                  Text(
                    section['title'] as String,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final paragraph
                      in section['paragraphs'] as List? ?? const [])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(
                        paragraph as String,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  for (final bullet in section['bullets'] as List? ?? const [])
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: SelectableText(
                        '• $bullet',
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                if (policy['contact_url'] != 'CONTACT_PENDING')
                  _link(
                    'Privacy contact: ${policy['contact_label']}',
                    policy['contact_url'] as String,
                  )
                else
                  const Text(
                    'Privacy contact details are awaiting confirmation. This policy is a draft.',
                  ),
                _link(
                  'Account deletion and data requests',
                  policy['deletion_url'] as String,
                ),
                _link(
                  'Google Privacy Policy',
                  'https://policies.google.com/privacy',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

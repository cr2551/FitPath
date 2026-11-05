import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';

/// Pure layout for About & disclaimer.
class AboutView extends StatelessWidget {
  const AboutView({
    super.key,
    required this.version,
    required this.privacyPolicyUrl,
    required this.onLicenses,
  });

  /// "0.1.0+1"; null while loading.
  final String? version;
  final String privacyPolicyUrl;
  final VoidCallback onLicenses;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    const gap = SizedBox(height: AppSpacing.md);
    Widget para(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: t.body),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              header: CardHeader(
                title: 'FitPath',
                subtitle: TextSpan(text: 'Version ${version ?? '…'}'),
              ),
              child: Text(
                'Track food, workouts and weight on your phone, offline.',
                style: t.body,
              ),
            ),
            gap,
            SectionCard(
              header: const CardHeader(
                icon: Icons.health_and_safety_outlined,
                title: 'Health disclaimer',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  para(
                    'FitPath is a tracking tool, not medical advice. BMI, '
                    'BMR, TDEE and the suggested calorie and macro targets '
                    'are estimates from standard formulas and can be wrong '
                    'for you.',
                  ),
                  para(
                    'Talk to a doctor or registered dietitian before big '
                    'changes to your diet or training, especially if you are '
                    'pregnant, under 18, have a medical condition or a '
                    'history of eating disorders.',
                  ),
                  Text(
                    'Food values come from labels and public databases and '
                    'may be incomplete or inaccurate.',
                    style: t.label,
                  ),
                ],
              ),
            ),
            gap,
            SectionCard(
              header: const CardHeader(
                icon: Icons.lock_outline,
                title: 'Your data',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  para(
                    'Everything you enter stays on this phone. There is no '
                    'account, no cloud sync, no ads and no analytics.',
                  ),
                  para(
                    'When you search for a packaged food, only the search '
                    'text or barcode is sent to Open Food Facts.',
                  ),
                  Text('Privacy policy', style: t.bodyStrong),
                  SelectableText(privacyPolicyUrl, style: t.label),
                ],
              ),
            ),
            gap,
            SectionCard(
              header: const CardHeader(
                icon: Icons.dataset_outlined,
                title: 'Data sources',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Open Food Facts', style: t.bodyStrong),
                  para(
                    'Packaged food data from Open Food Facts '
                    '(openfoodfacts.org), made available under the Open '
                    'Database License (ODbL). Contents are contributed by '
                    'the community and may contain errors.',
                  ),
                  Text('USDA FoodData Central', style: t.bodyStrong),
                  para(
                    'The built-in food list is based on USDA FoodData '
                    'Central (fdc.nal.usda.gov), public domain, rounded.',
                  ),
                  Text('Fonts', style: t.bodyStrong),
                  Text(
                    'Barlow and Barlow Condensed, by The Barlow Project '
                    'Authors, SIL Open Font License 1.1.',
                    style: t.body,
                  ),
                ],
              ),
            ),
            gap,
            SectionCard(
              child: ListRow(
                title: 'Open-source licences',
                subtitle: 'Libraries FitPath is built with',
                onTap: onLicenses,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

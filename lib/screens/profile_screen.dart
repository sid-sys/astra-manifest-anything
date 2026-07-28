import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import 'paywall_screen.dart';

/// Profile, settings and the monthly practice meter.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final region = ref.watch(regionServiceProvider);
    final downloads = ref
        .watch(storiesProvider)
        .where((story) => story.downloaded)
        .length;
    final practised = ref.watch(daysPractisedThisMonthProvider);
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Wordmark('Profile'),
        const SizedBox(height: AstraSpacing.xl),
        Center(
          child: Column(
            children: [
              GlyphDot(
                glyph: profile.name.isEmpty
                    ? '✦'
                    : profile.name.characters.first.toUpperCase(),
                size: 68,
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text(profile.name, style: AstraTextStyles.label.copyWith(fontSize: 16)),
              Text(
                'Manifesting since ${DateFormat('MMMM yyyy').format(profile.joinedAt)}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        _SettingRow(
          label: 'Intentions & life details',
          value: profile.intentions.map((i) => i.label).join(', '),
          onTap: () => _editIntentions(context, ref),
        ),
        _SettingRow(
          label: 'Daily reminder',
          value: _formatTime(profile.reminderHour, profile.reminderMinute),
          onTap: () => _pickReminder(context, ref),
        ),
        _SettingRow(
          label: 'Region & currency',
          value: '${region.countryCode} · ${region.currencyCode}',
          onTap: () => _pickRegion(context, ref),
        ),
        _SettingRow(
          label: 'Offline downloads',
          value: '$downloads ${downloads == 1 ? 'story' : 'stories'}',
        ),

        AstraCard(
          onTap: profile.isSubscribed
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const PaywallScreen(),
                    ),
                  ),
          child: Row(
            children: [
              Expanded(child: Text('Subscription', style: AstraTextStyles.body)),
              TagChip(
                label: profile.isSubscribed ? 'Plus' : 'Free',
                selected: profile.isSubscribed,
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This month', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              AstraProgressBar(value: practised / daysInMonth),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                '$practised of $daysInMonth days practised',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickReminder(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: profile.reminderHour,
        minute: profile.reminderMinute,
      ),
    );
    if (picked == null) return;

    await ref.read(profileProvider.notifier).update(
          profile.copyWith(
            reminderHour: picked.hour,
            reminderMinute: picked.minute,
          ),
        );
  }

  /// Lets someone travelling, on a VPN, or living away from their SIM's
  /// country correct what the device guessed.
  Future<void> _pickRegion(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AstraColors.inkRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Region', style: AstraTextStyles.display(20)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Sets the currency your plans are priced in.',
                style: AstraTextStyles.bodyDim,
              ),
            ),
            ListTile(
              title: Text('India — ₹ INR', style: AstraTextStyles.body),
              onTap: () => Navigator.of(sheetContext).pop('IN'),
            ),
            ListTile(
              title: Text('Rest of world — \$ USD', style: AstraTextStyles.body),
              onTap: () => Navigator.of(sheetContext).pop('US'),
            ),
            const SizedBox(height: AstraSpacing.sm),
          ],
        ),
      ),
    );

    if (picked == null) return;
    await ref
        .read(profileProvider.notifier)
        .update(profile.copyWith(countryOverride: picked));
  }

  Future<void> _editIntentions(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final selected = {...profile.intentions};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AstraColors.inkRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Intentions', style: AstraTextStyles.display(20)),
                const SizedBox(height: AstraSpacing.md),
                Wrap(
                  spacing: AstraSpacing.sm,
                  runSpacing: AstraSpacing.sm,
                  children: [
                    for (final intention in Intention.values)
                      TagChip(
                        label: '${intention.glyph}  ${intention.label}',
                        selected: selected.contains(intention),
                        accent: intention.accent,
                        onTap: () => setSheetState(() {
                          selected.contains(intention)
                              ? selected.remove(intention)
                              : selected.add(intention);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AstraSpacing.lg),
                AstraButton(
                  label: 'Save',
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;
    await ref
        .read(profileProvider.notifier)
        .update(profile.copyWith(intentions: selected));
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AstraSpacing.sm),
    child: AstraCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AstraTextStyles.body)),
          Flexible(
            child: Text(
              value,
              style: AstraTextStyles.bodyDim,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AstraColors.dim),
        ],
      ),
    ),
  );
}

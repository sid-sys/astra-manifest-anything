import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import 'astra_widgets.dart';

/// Why someone is flagging a piece of generated content.
///
/// A fixed list rather than free text alone, because a reviewer working
/// through a queue needs to triage fast — "sexual content" sorts differently
/// from "wrong name" — and a free-text box is still offered underneath for
/// anything the list does not cover.
enum ReportReason {
  inappropriate('Sexual, violent or otherwise inappropriate'),
  offensive('Offensive or discriminatory language'),
  wrongPerson('Got a name, gender or detail wrong'),
  distressing('Upsetting or made me feel worse'),
  other('Something else');

  const ReportReason(this.label);

  final String label;
}

/// Flags a story or an affirmation line.
///
/// Called from [player_screen.dart] — one
/// sheet, so a report always looks and behaves the same regardless of which
/// screen it was filed from, and Play's Generative AI policy is answered once
/// rather than twice in slightly different ways.
Future<void> reportContent(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  required String contentId,
  required String excerpt,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    backgroundColor: AstraColors.canvasRaised,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report this', style: AstraTextStyles.display(20)),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                'Nobody reviews what Maya writes before you see it. If '
                'something in here was wrong to generate, tell us and we will '
                'look at it.',
                style: AstraTextStyles.bodyDim,
              ),
              const SizedBox(height: AstraSpacing.lg),
              for (final option in ReportReason.values) ...[
                AstraCard(
                  onTap: () => Navigator.of(sheetContext).pop(option),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(option.label, style: AstraTextStyles.body),
                ),
                const SizedBox(height: AstraSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  if (reason == null) return;

  try {
    await ref
        .read(repositoryProvider)
        .submitReport(
          kind: kind,
          contentId: contentId,
          excerpt: excerpt,
          reason: reason.label,
        );

    // Confirmed rather than assumed: `submitReport` throws if the write
    // failed, and this line only runs once Firestore has accepted it — so the
    // toast is telling the truth about what happened, not what was attempted.
    messenger.showSnackBar(
      const SnackBar(content: Text('Reported. Thank you — we will look at it.')),
    );
  } catch (error) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not send the report. Check your connection and try again.'),
      ),
    );
  }
}

/// The flag icon used on both the player and the affirmation card. Small and
/// quiet on purpose — a report control that competes visually with the play
/// button gets pressed by accident, and one that cannot be found does not get
/// used at all. Grey until pressed, like the rest of the app's secondary
/// controls.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Report this content',
    child: Semantics(
      button: true,
      label: 'Report this content',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.flag_outlined, size: 18, color: AstraColors.dim),
        ),
      ),
    ),
  );
}

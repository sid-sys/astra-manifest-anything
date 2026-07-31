import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/journal_entry.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';

/// The evidence log — small proofs that the practice is landing in real life.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Wordmark('Journal'),
        const SizedBox(height: AstraSpacing.lg),
        Text('Evidence log', style: AstraTextStyles.display(28)),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          "Small proofs that it's already working.",
          style: AstraTextStyles.bodyDim,
        ),
        const SizedBox(height: AstraSpacing.xl),

        AstraCard(
          borderColor: AstraColors.gold,
          onTap: () => _compose(context, ref),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Write tonight's entry…",
                  style: AstraTextStyles.bodyDim,
                ),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: AstraColors.gold),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.md),

        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AstraSpacing.xl),
            child: Text(
              'Nothing logged yet. Start with one thing that went right today '
              '— however small.',
              textAlign: TextAlign.center,
              style: AstraTextStyles.bodyDim,
            ),
          )
        else
          for (final entry in entries) ...[
            _EntryCard(
              entry: entry,
              onDelete: () =>
                  ref.read(journalProvider.notifier).remove(entry.id),
            ),
            const SizedBox(height: AstraSpacing.sm),
          ],
      ],
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<_Draft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AstraColors.inkRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _JournalComposer(),
    );

    if (draft == null) return;

    await ref.read(journalProvider.notifier).add(
          JournalEntry(
            id: 'entry_${DateTime.now().microsecondsSinceEpoch}',
            body: draft.body,
            kind: draft.kind,
            createdAt: DateTime.now(),
          ),
        );
  }
}

typedef _Draft = ({String body, JournalKind kind});

/// The new-entry sheet.
///
/// A widget rather than a `StatefulBuilder` because it has to own the text
/// controller. Disposing the controller once the sheet's future completed
/// killed it while the sheet was still animating out and still rebuilding the
/// field, which threw "A TextEditingController was used after being disposed"
/// and took the whole screen down with it. Owning it here means it lives
/// exactly as long as the route does.
class _JournalComposer extends StatefulWidget {
  const _JournalComposer();

  @override
  State<_JournalComposer> createState() => _JournalComposerState();
}

class _JournalComposerState extends State<_JournalComposer> {
  final _controller = TextEditingController();
  JournalKind _kind = JournalKind.gratitude;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    Navigator.of(context).pop((body: body, kind: _kind));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New entry', style: AstraTextStyles.display(20)),
        const SizedBox(height: AstraSpacing.md),
        Wrap(
          spacing: AstraSpacing.sm,
          children: [
            for (final option in JournalKind.values)
              TagChip(
                label: option.label,
                selected: option == _kind,
                onTap: () => setState(() => _kind = option),
              ),
          ],
        ),
        const SizedBox(height: AstraSpacing.md),
        AstraCard(
          child: TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            style: AstraTextStyles.body,
            cursorColor: AstraColors.gold,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'A recruiter reached out about a design lead role…',
              hintStyle: AstraTextStyles.bodyDim,
            ),
          ),
        ),
        const SizedBox(height: AstraSpacing.lg),
        AstraButton(
          label: 'Save entry',
          // Disabled while empty, so the sheet cannot close on nothing and
          // leave the user wondering where their entry went.
          onPressed: _hasText ? _save : null,
        ),
        const SizedBox(height: AstraSpacing.sm),
      ],
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onDelete});

  final JournalEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_relativeDay(entry.createdAt)} · ${entry.kind.label}',
                style: AstraTextStyles.small,
              ),
            ),
            InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 15, color: AstraColors.dim),
              ),
            ),
          ],
        ),
        const SizedBox(height: AstraSpacing.xs),
        Text(entry.body, style: AstraTextStyles.body),
      ],
    ),
  );

  static String _relativeDay(DateTime when) {
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;

    return switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      < 7 => '$days days ago',
      _ => DateFormat('d MMM').format(when),
    };
  }
}

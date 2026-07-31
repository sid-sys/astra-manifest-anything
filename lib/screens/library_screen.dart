import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../models/story.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import 'player_screen.dart';

/// Every story the user owns, filterable by intention.
///
/// There is no daily listen cap here by design: a story you generated is a
/// story you can play as often as you like.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Intention? _filter;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(storiesProvider);
    final stories =
        _filter == null ? all : all.where((s) => s.intention == _filter).toList();
    final usedIntentions = {for (final story in all) story.intention};

    if (all.isEmpty) {
      return EmptyState(
        glyph: '✦',
        title: 'Your library is waiting',
        body: 'Stories you weave are kept here — filterable, replayable, and '
            'available offline.',
        action: AstraButton(
          label: 'Weave your first story',
          icon: Icons.auto_awesome,
          onPressed: widget.onCreate,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Wordmark('Library'),
        const SizedBox(height: AstraSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TagChip(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final intention in usedIntentions) ...[
                const SizedBox(width: AstraSpacing.sm),
                TagChip(
                  label: intention.label,
                  selected: _filter == intention,
                  accent: intention.accent,
                  onTap: () => setState(() => _filter = intention),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.lg),

        for (final story in stories) ...[
          _StoryRow(
            story: story,
            onPlay: () {
              final queue = stories.where((s) => s.id != story.id).toList();
              ref.read(playbackProvider).play(story, queue: queue);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
              );
            },
            onQueue: () {
              ref.read(playbackProvider).enqueue(story);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Queued “${story.title}”')),
              );
            },
            onDelete: () => ref.read(storiesProvider.notifier).remove(story.id),
          ),
          const SizedBox(height: AstraSpacing.sm),
        ],

        const SizedBox(height: AstraSpacing.sm),
        AstraGhostButton(label: '＋  New story', onPressed: widget.onCreate),
      ],
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.story,
    required this.onPlay,
    required this.onQueue,
    required this.onDelete,
  });

  final Story story;
  final VoidCallback onPlay;
  final VoidCallback onQueue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AstraCard(
    onTap: onPlay,
    child: Row(
      children: [
        GlyphDot(glyph: story.intention.glyph, color: story.intention.accent),
        const SizedBox(width: AstraSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.title,
                style: AstraTextStyles.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${story.durationLabel} · ${story.intention.label}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: AstraColors.dim, size: 20),
          color: AstraColors.cardRaised,
          tooltip: 'Story options',
          onSelected: (value) => switch (value) {
            'queue' => onQueue(),
            'delete' => onDelete(),
            _ => null,
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );
}

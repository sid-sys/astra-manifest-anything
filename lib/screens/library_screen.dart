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
  const LibraryScreen({super.key, required this.onWrite});

  /// Sends the user to Home, which is where writing starts.
  final VoidCallback onWrite;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Intention? _filter;

  @override
  Widget build(BuildContext context) {
    // Manifestations and stories in one list, newest first.
    //
    // Nothing new is written as a story any more, but every story ever written
    // is still here and still plays. Deleting them would take back audio people
    // paid for, and a second "old stories" tab would be a museum nobody visits.
    // They are the same thing to listen to, so they are one list.
    final all = ref.watch(everythingWrittenProvider);

    final stories =
        _filter == null ? all : all.where((s) => s.intention == _filter).toList();
    final usedIntentions = {for (final story in all) story.intention};

    if (all.isEmpty) {
      return EmptyState(
        glyph: '✦',
        mascot: 'mascot_sleep',
        title: 'Your library is waiting',
        body: 'Everything Mayow writes for you is kept here — replayable, for '
            'as long as you want it.',
        action: AstraButton(
          label: 'Write your first manifestation',
          icon: Icons.auto_awesome,
          onPressed: widget.onWrite,
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
              // Opened, not started. Pressing play is the user's call — see
              // [PlaybackController.open].
              ref.read(playbackProvider).open(story, queue: queue);
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
            onDelete: () async {
              final sure = await confirmDelete(
                context,
                'Delete “${story.title}”?',
              );
              if (!sure || !mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                // Manifestations live in their own collection, so removing
                // them from the stories list alone deleted nothing on the
                // server — a delete on a document that was never there
                // succeeds silently, so the mistake never even showed an
                // error, only an item that refused to go away.
                //
                // Which collection a story is actually in is asked of the
                // list itself rather than guessed from its id. The prefix
                // check this used to be — `id.startsWith('manifest_')` — is
                // true for every manifestation [ManifestService.write]
                // makes today, but not for one written before that
                // convention existed, and there is no way to tell the two
                // apart by looking at the id alone.
                final isManifestation = ref
                    .read(manifestationsProvider)
                    .valueOrNull
                    ?.any((m) => m.id == story.id) ??
                    story.id.startsWith('manifest_');

                if (isManifestation) {
                  await ref.read(manifestServiceProvider).delete(story.id);
                  ref.invalidate(manifestationsProvider);
                } else {
                  await ref.read(storiesProvider.notifier).remove(story.id);
                }
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not delete — try again ($error).'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: AstraSpacing.sm),
        ],
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
  final Future<void> Function() onDelete;

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
          icon: Icon(Icons.more_horiz, color: AstraColors.dim, size: 20),
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

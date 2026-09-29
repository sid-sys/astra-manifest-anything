import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/admin_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// Write one message, send it to every phone, then see who opened it.
///
/// Its own screen rather than another card on the admin panel, because this is
/// the one control in the app that reaches every user at once and it should
/// take a deliberate trip to get to. The confirmation before sending says the
/// number out loud for the same reason.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  late Future<List<Broadcast>> _sent;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _sent = ref.read(adminServiceProvider).broadcasts();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// The message is the whole requirement. A title is optional, because
  /// Android draws the app name in the header when there is none — so a short
  /// announcement reads better without one than with a second heading above it.
  bool get _ready => !_sending && _body.text.trim().length >= 10;

  Future<void> _refresh() async {
    final next = ref.read(adminServiceProvider).broadcasts();
    setState(() {
      _sent = next;
    });

    try {
      await next;
    } catch (error) {
      debugPrint('Maya: broadcast list failed — $error');
    }
  }

  Future<void> _send() async {
    if (!_ready || !await _confirm()) return;
    if (!mounted) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final sent = await ref
          .read(adminServiceProvider)
          .broadcast(title: _title.text.trim(), body: _body.text.trim());

      _title.clear();
      _body.clear();
      await _refresh();
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${sent.delivered} of ${sent.recipients} devices.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Asked because this cannot be taken back.
  ///
  /// A notification is delivered the moment it is sent. There is no unsend, no
  /// edit, and no way to reach the people who already read it — so the only
  /// place to catch a typo is before the button, which is what this is for.
  Future<bool> _confirm() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AstraColors.card,
          title: Text('Send to everyone?', style: AstraTextStyles.display(20)),
          content: Text(
            'Every phone with notifications turned on gets this, straight '
            'away. It cannot be edited or taken back.\n\n'
            // Shown the way the phone will show it: no title line when there
            // is no title, rather than a pair of empty quotation marks.
            '${_title.text.trim().isEmpty ? '' : '“${_title.text.trim()}”\n'}'
            '${_body.text.trim()}',
            style: AstraTextStyles.bodyDim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AstraTextStyles.small),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Send',
                style: AstraTextStyles.small.copyWith(
                  color: AstraColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AstraColors.text,
          backgroundColor: AstraColors.card,
          child: ListView(
            padding: AstraSpacing.screenPadding,
            children: [
              const SizedBox(height: AstraSpacing.sm),
              Row(
                children: [
                  _Back(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: AstraSpacing.md),
                  Text('Maya', style: AstraTextStyles.wordmark),
                ],
              ),
              const SizedBox(height: AstraSpacing.xl),
              Text('ADMIN', style: AstraTextStyles.eyebrow),
              const SizedBox(height: AstraSpacing.xs),
              Text('Tell everyone', style: AstraTextStyles.display(26)),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                'One message, every phone with notifications on. Use it when '
                'something real has changed — a push nobody asked for is the '
                'fastest way to be uninstalled.',
                style: AstraTextStyles.bodyDim,
              ),
              const SizedBox(height: AstraSpacing.xl),

              AstraCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TITLE — OPTIONAL', style: AstraTextStyles.eyebrow),
                    const SizedBox(height: AstraSpacing.xs),
                    _Field(
                      controller: _title,
                      hint: 'Leave blank to show just the message',
                      maxLength: 80,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AstraSpacing.md),
                    Text('MESSAGE', style: AstraTextStyles.eyebrow),
                    const SizedBox(height: AstraSpacing.xs),
                    _Field(
                      controller: _body,
                      hint: 'Open the app to see what changed.',
                      maxLength: 400,
                      lines: 4,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AstraSpacing.lg),
                    AstraButton(
                      label: '📣  Send to everyone',
                      busy: _sending,
                      onPressed: _ready ? _send : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AstraSpacing.xl),
              Text('SENT', style: AstraTextStyles.eyebrow),
              const SizedBox(height: AstraSpacing.sm),

              FutureBuilder<List<Broadcast>>(
                future: _sent,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: AstraSpacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      '${snapshot.error}',
                      style: AstraTextStyles.small.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }

                  final sent = snapshot.data ?? const <Broadcast>[];
                  if (sent.isEmpty) {
                    return Text(
                      'Nothing sent yet.',
                      style: AstraTextStyles.bodyDim,
                    );
                  }

                  return Column(
                    children: [
                      for (final one in sent) ...[
                        _BroadcastCard(broadcast: one),
                        const SizedBox(height: AstraSpacing.sm),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: AstraSpacing.lg),
              Text(
                // Said plainly, because the number invites the wrong reading.
                'Opened means somebody tapped the notification. A phone can be '
                'sent one, show it, and never be tapped — so everyone who is '
                'not in the opened list is unknown rather than uninterested.',
                style: AstraTextStyles.small,
              ),
              const SizedBox(height: AstraSpacing.xxl),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One announcement, with its counts, opening to who got it.
class _BroadcastCard extends ConsumerStatefulWidget {
  const _BroadcastCard({required this.broadcast});

  final Broadcast broadcast;

  @override
  ConsumerState<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends ConsumerState<_BroadcastCard> {
  Future<List<BroadcastRecipient>>? _people;

  void _toggle() {
    setState(() {
      _people = _people == null
          ? ref.read(adminServiceProvider).recipients(widget.broadcast.id)
          : null;
    });
  }

  static String _when(DateTime? at) {
    if (at == null) return 'unknown';
    final local = at.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]}, ${local.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final one = widget.broadcast;

    return AstraCard(
      onTap: _toggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // An announcement sent without a title is listed by its
                  // message, which is what the phone showed anyway.
                  one.title.isEmpty ? one.body : one.title,
                  style: AstraTextStyles.label.copyWith(fontSize: 15),
                ),
              ),
              Text(
                '${one.opened} of ${one.delivered}',
                style: AstraTextStyles.small.copyWith(color: AstraColors.text),
              ),
            ],
          ),
          if (one.title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(one.body, style: AstraTextStyles.small),
          ],
          const SizedBox(height: AstraSpacing.xs),
          Text(
            '${_when(one.sentAt)} · ${one.recipients} addressed'
            '${one.failed > 0 ? ' · ${one.failed} could not be reached' : ''}',
            style: AstraTextStyles.small.copyWith(color: AstraColors.dim),
          ),

          if (_people != null) ...[
            const SizedBox(height: AstraSpacing.md),
            FutureBuilder<List<BroadcastRecipient>>(
              future: _people,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final people = snapshot.data ?? const <BroadcastRecipient>[];
                if (people.isEmpty) {
                  return Text('Nobody.', style: AstraTextStyles.small);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final person in people)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              person.opened
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 14,
                              color: person.opened
                                  ? AstraColors.accent
                                  : AstraColors.dim,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                person.email ?? person.uid,
                                style: AstraTextStyles.small.copyWith(
                                  color: person.opened
                                      ? AstraColors.text
                                      : AstraColors.dim,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!person.delivered)
                              Text(
                                'not reached',
                                style: AstraTextStyles.small.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.maxLength,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final int maxLength;
  final int lines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: AstraTextStyles.body,
    cursorColor: AstraColors.accent,
    minLines: lines,
    maxLines: lines,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.sentences,
    onChanged: (_) => onChanged(),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AstraTextStyles.bodyDim,
      filled: true,
      fillColor: AstraColors.canvas,
      counterStyle: AstraTextStyles.small,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AstraColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AstraColors.line),
      ),
    ),
  );
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AstraColors.line),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 18, color: AstraColors.text),
      ),
    ),
  );
}

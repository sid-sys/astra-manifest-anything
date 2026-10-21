import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// A box to tell us what is wrong or what you would like. Goes to the person
/// who runs Mayow and nowhere else.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  bool _bug = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready => _text.text.trim().length >= 3;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(feedbackServiceProvider).send(text: _text.text, bug: _bug);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thank you. We read every one.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message ?? 'Could not send that. Try again in a moment.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send that. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: Padding(
          padding: AstraSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AstraColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AstraColors.line),
                    ),
                    child: const AstraIcon('ui_back', size: 26),
                  ),
                ),
              ),
              const SizedBox(height: AstraSpacing.lg),
              Text('Tell us', style: AstraTextStyles.display(28)),
              const SizedBox(height: 4),
              Text(
                'What is not working, or what would you like?',
                style: AstraTextStyles.bodyDim,
              ),
              const SizedBox(height: AstraSpacing.lg),
              Wrap(
                spacing: 8,
                children: [
                  TagChip(
                    label: 'Feedback',
                    selected: !_bug,
                    onTap: () => setState(() => _bug = false),
                  ),
                  TagChip(
                    label: 'A bug',
                    selected: _bug,
                    onTap: () => setState(() => _bug = true),
                  ),
                ],
              ),
              const SizedBox(height: AstraSpacing.md),
              Expanded(
                child: TextField(
                  controller: _text,
                  onChanged: (_) => setState(() {}),
                  maxLength: 1500,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  style: AstraTextStyles.body,
                  cursorColor: AstraColors.accent,
                  decoration: InputDecoration(
                    hintText: _bug
                        ? 'What happened, and what did you expect?'
                        : 'Write anything you like.',
                    hintStyle: AstraTextStyles.bodyDim,
                    filled: true,
                    fillColor: AstraColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AstraColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AstraColors.line),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: AstraTextStyles.small.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AstraSpacing.md),
              AstraButton(
                label: 'Send',
                busy: _busy,
                onPressed: _ready && !_busy ? _send : null,
              ),
              const SizedBox(height: AstraSpacing.md),
            ],
          ),
        ),
      ),
    ),
  );
}

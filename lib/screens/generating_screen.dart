import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';

/// Shown while a story is being written and narrated.
///
/// It gets a whole screen rather than a spinner on a button because the wait is
/// about a minute — long enough that a button that merely looks busy reads as a
/// hang. Naming the two stages also makes the wait legible: the user can see
/// that something slow is meant to be slow.
class GeneratingScreen extends StatelessWidget {
  const GeneratingScreen({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving mid-generation would orphan the story: the function keeps going
    // and the audio is still paid for, so there is nothing to gain by backing
    // out and a story to lose.
    canPop: false,
    child: Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: AstraSpacing.screenPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AstraColors.accent,
                    ),
                  ),
                  const SizedBox(height: AstraSpacing.xl),
                  Text(
                    'Writing your story',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.display(26),
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    'You can read it in a moment.\n'
                    'The narration records while you do.',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

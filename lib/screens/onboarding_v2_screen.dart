import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// Four short questions asked once, before Home is shown for the first time.
///
/// Not the twelve-question flow this app used to run at signup — that one is
/// gone, and gone for a documented reason: those answers described a wish
/// that had not been typed yet. This flow asks nothing about a wish. It asks
/// about the person's own belief and habits, which do not change from one
/// manifestation to the next, and it writes only two things anyone downstream
/// reads: which life areas to weight [Intention] toward, and when to send a
/// reminder. The rest — belief, importance — are stored for tone, not shown
/// back to anyone.
class OnboardingV2Screen extends ConsumerStatefulWidget {
  const OnboardingV2Screen({super.key});

  @override
  ConsumerState<OnboardingV2Screen> createState() =>
      _OnboardingV2ScreenState();
}

class _OnboardingV2ScreenState extends ConsumerState<OnboardingV2Screen> {
  final _controller = PageController();
  int _page = 0;

  String? _belief;
  final Set<Intention> _areas = {};
  String? _importance;
  String? _reminderPref;

  /// Whether the person said yes to the system notification prompt on the
  /// reminder question. Written to the profile in [_finish].
  bool _allowed = false;
  bool _busy = false;

  static const _pageCount = 6; // welcome, 4 questions, ready

  bool get _canContinue => switch (_page) {
    0 => true,
    1 => _belief != null,
    2 => _areas.isNotEmpty,
    3 => _importance != null,
    4 => _reminderPref != null,
    _ => true,
  };

  /// True on the reminder question once they picked a time other than "later".
  bool get _asksPermission =>
      _page == 4 && _reminderPref != null && _reminderPref != 'later';

  Future<void> _next() async {
    if (!_canContinue || _busy) return;

    // The ask happens here, on the page that explains it, straight after the
    // person says when they want to be reminded — not two screens later, when
    // the reason has gone cold. The system dialog is Android's own and says
    // nothing about why, so the page above it has to.
    if (_asksPermission) {
      setState(() => _busy = true);
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (!mounted) return;
      setState(() {
        _allowed = granted;
        _busy = false;
      });
    }

    if (_page == _pageCount - 1) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    // The reminder question decides which of the two daily slots this
    // account gets, not just what is stored for later — a "morning" answer
    // that only wrote itself down and left both switches on would have
    // sent the evening line anyway.
    final (sendMorning, sendEvening) = switch (_reminderPref) {
      'morning' => (true, false),
      'evening' => (false, true),
      'both' => (true, true),
      _ => (true, true), // 'later': undecided, not off — the permission
      // screen right after this is where "on or off" is actually settled.
    };

    // The push address, fetched before saving: saving `onboardingV2Done` is
    // what moves the app on, and this screen is gone the moment it lands.
    final registration = _allowed
        ? await ref.read(notificationServiceProvider).register()
        : null;
    if (!mounted) return;

    // Reported before saving: saving moves the app on, and this screen is gone
    // the moment it lands.
    unawaited(ref.read(trackingProvider).log('onboarding_done'));

    await ref.read(profileProvider.notifier).update(
      ref.read(profileProvider).copyWith(
        fcmToken: registration?.token,
        trialPushToken: registration?.token,
        timezone: registration?.zone,
        belief: _belief,
        intentions: _areas,
        importance: _importance,
        reminderPref: _reminderPref,
        onboardingV2Done: true,
        sendMorning: sendMorning,
        sendEvening: sendEvening,
        remindersOn: _allowed,
      ),
    );
    // Nothing to navigate to. Saving `onboardingV2Done` is what moves the app
    // on: `app.dart` is watching it, and shows the paywall to a new account
    // or Home to anyone else.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              const SizedBox(height: AstraSpacing.sm),
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Wordmark('Mayow'),
                    if (_page > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _Back(onTap: _back),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AstraSpacing.md),
              _Dots(count: _pageCount - 1, index: _page.clamp(0, _pageCount - 2)),
              const SizedBox(height: AstraSpacing.lg),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    _Welcome(onNext: _next),
                    _Belief(
                      value: _belief,
                      onChanged: (v) => setState(() => _belief = v),
                    ),
                    _Areas(
                      selected: _areas,
                      onToggle: (area) => setState(
                        () => _areas.contains(area)
                            ? _areas.remove(area)
                            : _areas.add(area),
                      ),
                    ),
                    _Importance(
                      value: _importance,
                      onChanged: (v) => setState(() => _importance = v),
                    ),
                    _ReminderPref(
                      value: _reminderPref,
                      onChanged: (v) => setState(() => _reminderPref = v),
                    ),
                    const _Ready(),
                  ],
                ),
              ),
              const SizedBox(height: AstraSpacing.md),
              AstraButton(
                label: switch (_page) {
                  0 => 'Get Started',
                  4 when _asksPermission => 'Allow notifications',
                  5 => 'Continue to Mayow',
                  _ => 'Continue',
                },
                busy: _busy,
                onPressed: _canContinue ? _next : null,
              ),
              const SizedBox(height: AstraSpacing.sm),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++) ...[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == index ? AstraColors.text : AstraColors.line,
          ),
        ),
        if (i != count - 1) const SizedBox(width: 8),
      ],
    ],
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
        child: const Center(child: AstraIcon('ui_back', size: 26)),
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: AstraSpacing.lg),
      // Mayow herself, waving. The rings behind her are drawn by the page
      // background, so she sits at the centre of them like a logo would.
      const Center(child: AstraMascot('mascot_wave', size: 230)),
      const SizedBox(height: AstraSpacing.xl),
      Text(
        'Turn your wish into a moment you can feel.',
        textAlign: TextAlign.center,
        style: AstraTextStyles.display(30),
      ),
      const SizedBox(height: AstraSpacing.md),
      Text(
        'Tell Mayow what you\'re working toward. It writes a personal guided '
        'manifestation you can listen to again and again — and five '
        'affirmations to say and believe, every day, for free.',
        textAlign: TextAlign.center,
        style: AstraTextStyles.bodyDim,
      ),
    ],
  );
}

class _Belief extends StatelessWidget {
  const _Belief({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('absolutely', 'Absolutely'),
    ('i-think-so', 'I think so'),
    ('not-sure', 'I\'m not sure yet'),
    ('not-really', 'Not really'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: AstraSpacing.lg),
      Text('Do you believe your thoughts\ncan shape your reality?',
          style: AstraTextStyles.display(24)),
      const SizedBox(height: AstraSpacing.xs),
      Text('Choose what feels closest to you.', style: AstraTextStyles.bodyDim),
      const SizedBox(height: AstraSpacing.lg),
      for (final (key, label) in _options) ...[
        _Choice(label: label, selected: value == key, onTap: () => onChanged(key)),
        const SizedBox(height: AstraSpacing.sm),
      ],
    ],
  );
}

class _Areas extends StatelessWidget {
  const _Areas({required this.selected, required this.onToggle});

  final Set<Intention> selected;
  final ValueChanged<Intention> onToggle;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: AstraSpacing.lg),
      Text('What would you most like\nto change in your life?',
          style: AstraTextStyles.display(24)),
      const SizedBox(height: AstraSpacing.xs),
      Text('Pick as many as fit.', style: AstraTextStyles.bodyDim),
      const SizedBox(height: AstraSpacing.lg),
      Wrap(
        spacing: AstraSpacing.sm,
        runSpacing: AstraSpacing.sm,
        children: [
          for (final area in Intention.values)
            TagChip(
              label: '${area.glyph}  ${area.label}',
              selected: selected.contains(area),
              onTap: () => onToggle(area),
            ),
        ],
      ),
    ],
  );
}

class _Importance extends StatelessWidget {
  const _Importance({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('not-sure', 'Not sure yet'),
    ('would-like-it', 'I\'d really like it'),
    ('very-important', 'It\'s very important'),
    ('ready-to-change', 'I\'m ready to change'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: AstraSpacing.lg),
      Text('How important is this\nchange to you?', style: AstraTextStyles.display(24)),
      const SizedBox(height: AstraSpacing.lg),
      for (final (key, label) in _options) ...[
        _Choice(label: label, selected: value == key, onTap: () => onChanged(key)),
        const SizedBox(height: AstraSpacing.sm),
      ],
    ],
  );
}

class _ReminderPref extends StatelessWidget {
  const _ReminderPref({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('morning', '☀️  Morning — start my day with intention'),
    ('evening', '🌙  Evening — end my day with intention'),
    ('both', '☀️🌙  Both — keep my goal close all day'),
    ('later', 'I\'ll decide later'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: AstraSpacing.lg),
      Text(
        'When should Mayow remind\nyou of your goal?',
        style: AstraTextStyles.display(24),
      ),
      const SizedBox(height: AstraSpacing.lg),
      for (final (key, label) in _options) ...[
        _Choice(label: label, selected: value == key, onTap: () => onChanged(key)),
        const SizedBox(height: AstraSpacing.sm),
      ],
      const SizedBox(height: AstraSpacing.sm),

      // Why, in plain words, before Android asks. Changes with the answer so it
      // never promises a reminder the person just said they did not want.
      AstraCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AstraIcon('ui_bell', size: 38),
            const SizedBox(width: AstraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value == 'later'
                        ? 'No reminders for now'
                        : 'Why Mayow asks to send notifications',
                    style: AstraTextStyles.label,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value == 'later'
                        ? 'You can switch them on any time in Profile. Until '
                              'then nothing will be sent.'
                        : 'A reminder is what turns this into a habit. '
                              '${switch (value) {
                                'morning' => 'Your morning affirmation',
                                'evening' => 'Your evening affirmation',
                                _ => 'Your morning and evening affirmations',
                              }} '
                              'will arrive as a notification, and Mayow will '
                              'tell you when a manifestation you asked for is '
                              'ready. Never more than two a day otherwise. '
                              'Without notifications, nothing reaches you.',
                    style: AstraTextStyles.small,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Ready extends StatelessWidget {
  const _Ready();

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const Center(child: AstraMascot('mascot_cheer', size: 170)),
      const SizedBox(height: AstraSpacing.md),
      Text('You already know what\nyou want.', style: AstraTextStyles.display(28)),
      const SizedBox(height: AstraSpacing.md),
      Text(
        'Mayow helps you turn that intention into something you can return to '
        'every day.',
        style: AstraTextStyles.bodyDim,
      ),
      const SizedBox(height: AstraSpacing.xl),
      Text('YOUR MAYOW EXPERIENCE', style: AstraTextStyles.eyebrow),
      const SizedBox(height: AstraSpacing.sm),
      for (final line in const [
        '✦  A personal manifestation, from your own words',
        '✦  Five affirmations, free always',
        '✦  Morning and evening reminders',
        '✦  Your own private library',
      ]) ...[
        Text(line, style: AstraTextStyles.body),
        const SizedBox(height: AstraSpacing.xs),
      ],
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: selected ? AstraColors.accentWash : AstraColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AstraColors.accent : AstraColors.line,
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AstraTextStyles.body.copyWith(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (selected)
            const AstraIcon('ui_check', size: 30),
        ],
      ),
    ),
  );
}

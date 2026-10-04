import '../models/affirmation_set.dart';
import '../models/intention.dart';
import '../models/manifestation.dart';
import '../models/question_plan.dart';
import '../models/story.dart';
import '../models/user_profile.dart';
import '../services/plan_service.dart';

/// A furnished account, for taking store screenshots against.
///
/// The store listing asks for six frames, and five of them are pictures of
/// content: a manifestation playing, a full library, a set of affirmations, a
/// streak. An empty account photographs as an empty app, and the honest way to
/// fix that is to have something real in it — not to mock up a screen in a
/// design tool that the app cannot actually produce.
///
/// Nothing here reaches a real build. It is compiled in only when the app is
/// run with `--dart-define=ASTRA_DEMO=true`, which is a thing done by hand at a
/// terminal; the Play bundle is built without it, so this file is dead weight
/// the tree-shaker removes.
///
/// The writing below is copied in shape from what the model actually returns —
/// second person, present tense, one small concrete moment — because a
/// screenshot showing prose the app would never write is a promise it cannot
/// keep. A reviewer comparing the store page to the app should find the same
/// thing in both.
class Demo {
  const Demo._();

  /// On when the app was started with `--dart-define=ASTRA_DEMO=true`.
  static const on = bool.fromEnvironment('ASTRA_DEMO');

  /// Which screen to open on, read from the URL.
  ///
  /// `?screen=library`, `?screen=affirm`, `?screen=profile`, `?screen=questions`,
  /// `?screen=player`. Anything else, including nothing, opens Home.
  ///
  /// This exists because the store screenshots have to be taken the same way
  /// twice. Driving a Flutter canvas by clicking at pixel coordinates works
  /// once and then breaks the moment a font renders half a point differently;
  /// a URL that opens the screen directly is the same picture every time, and
  /// anyone can take it without being told where to tap.
  static String get screen {
    if (!on) return 'home';
    return Uri.base.queryParameters['screen'] ?? 'home';
  }

  /// A wish already typed into the box, for the Home frame.
  static String get wish =>
      Uri.base.queryParameters['wish'] ??
      'I want to wake up in a home that is actually mine';

  static final _now = DateTime.now();

  /// The bed track, standing in for narration.
  ///
  /// The player draws a different screen when a manifestation has no audio —
  /// a spinner and "Recording your narration", which is correct in the app and
  /// wrong in a store screenshot, since it photographs as a thing still
  /// loading. Pointing at an asset the build already ships gives the real
  /// player: a scrubber, a duration, the speed control.
  ///
  /// Relative, so it resolves against wherever the demo is being served.
  static const _audio = 'assets/assets/audio/meditation_bed.mp3';

  static DateTime _daysAgo(int days, {int hour = 8, int minute = 12}) {
    final day = _now.subtract(Duration(days: days));
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// The account the screenshots are taken from.
  ///
  /// Reminders are on and at the two default times, because the sixth frame is
  /// a picture of exactly that row.
  static UserProfile get profile => UserProfile(
    name: 'Sana',
    intentions: const {Intention.peace, Intention.abundance},
    aspiration: 'A home that is actually mine',
    voice: 'sage',
    joinedAt: _daysAgo(64),
    remindersOn: true,
    onboardingDone: true,
  );

  /// Four manifestations, newest first.
  ///
  /// Different areas of life on purpose: the library frame should show that the
  /// app is not only about money, and the titles are what the library lists, so
  /// they carry most of the meaning in that screenshot.
  static List<Manifestation> get manifestations => [
    Manifestation(
      id: 'demo_home',
      dream: 'I want to wake up in a home that is actually mine',
      script: _homeScript,
      duration: const Duration(minutes: 4, seconds: 12),
      createdAt: _daysAgo(0, hour: 7, minute: 4),
      audioUrl: _audio,
    ),
    Manifestation(
      id: 'demo_work',
      dream: 'I want to earn ten thousand a month from my own work',
      script: _workScript,
      duration: const Duration(minutes: 4, seconds: 3),
      createdAt: _daysAgo(1, hour: 21, minute: 40),
      audioUrl: _audio,
    ),
    Manifestation(
      id: 'demo_love',
      dream: 'I want to find my person',
      script: _loveScript,
      duration: const Duration(minutes: 3, seconds: 58),
      createdAt: _daysAgo(3, hour: 22, minute: 15),
      audioUrl: _audio,
    ),
    Manifestation(
      id: 'demo_run',
      dream: 'I want to run the whole way without stopping',
      script: _runScript,
      duration: const Duration(minutes: 4, seconds: 20),
      createdAt: _daysAgo(5, hour: 6, minute: 30),
      audioUrl: _audio,
    ),
  ];

  /// Older writing, one a day, so the streak and the week strip have a run to
  /// draw rather than a single day. Stories rather than manifestations only
  /// because a real account of this age would have both in it.
  static List<Story> get stories => [
    _story('demo_s1', 'The morning after the offer came', Intention.career, 2),
    _story('demo_s2', 'The flat with the long window', Intention.peace, 3),
    _story('demo_s3', 'Paying it off in one go', Intention.abundance, 4),
    _story('demo_s4', 'Walking in like I belonged there', Intention.confidence, 5),
    _story('demo_s5', 'The whole table, talking at once', Intention.love, 6),
    _story('demo_s6', 'Finishing without stopping', Intention.health, 7),
  ];

  static Story _story(
    String id,
    String title,
    Intention intention,
    int daysAgo,
  ) => Story(
    id: id,
    title: title,
    intention: intention,
    script: _homeScript,
    duration: const Duration(minutes: 4, seconds: 8),
    voice: 'sage',
    createdAt: _daysAgo(daysAgo),
    audioUrl: _audio,
    favorite: daysAgo.isEven,
  );

  /// The five lines the Affirm tab shows.
  ///
  /// Written the way the real prompt asks for them: believable, present tense,
  /// and specific to one wish. The point of that frame is the difference
  /// between these and "I am abundant", so they have to be the specific ones.
  static List<AffirmationSet> get affirmationSets => [
    AffirmationSet(
      id: 'demo_affirm_home',
      goal: 'I want to wake up in a home that is actually mine',
      createdAt: _daysAgo(0, hour: 7, minute: 6),
      lines: const [
        'I wake up each morning feeling peaceful and grateful in my beautiful '
            'apartment overlooking the city.',
        'My home feels calm, private, and completely aligned with the life I '
            'have created.',
        'I love coming home to a beautiful space that reflects my taste, '
            'success, and personality.',
        'I feel proud knowing I have created a comfortable home where I can '
            'truly relax and be myself.',
        'Every day, I experience more freedom, peace, and gratitude in the '
            'beautiful home I call my own.',
      ],
    ),
    AffirmationSet(
      id: 'demo_affirm_work',
      goal: 'I want to earn ten thousand a month from my own work',
      createdAt: _daysAgo(2, hour: 20, minute: 10),
      lines: const [
        'I am building work that pays me properly for what it is worth.',
        'Money arrives from my own effort, and it keeps arriving.',
        'I price my work honestly and people say yes.',
        'I am becoming the kind of person who is paid well and expects it.',
        'Every month I am steadier, and the number goes up.',
      ],
    ),
  ];

  /// The four questions for the third frame.
  ///
  /// Canned rather than written by the model, because the screenshot is taken
  /// with no server attached. They are copied from a real answer for the same
  /// wish, so the frame shows what a person would actually be asked — the whole
  /// argument of that screenshot is that the questions are *about the wish*,
  /// and generic stand-ins would quietly say the opposite.
  static QuestionPlan get plan => const QuestionPlan(
    category: 'Home',
    questions: [
      PlannedQuestion(
        question: 'What do you see first when you open your eyes there?',
        options: [
          '🌅  Light coming through a long window',
          '🌿  Plants, and a room that smells green',
          '🏙️  The city, still waking up below me',
          '🛏️  A quiet room and nowhere to be',
        ],
      ),
      PlannedQuestion(
        question: 'What makes it feel like yours and nobody else’s?',
        options: [
          '🔑  The keys are in my name',
          '🎨  Every wall is a colour I chose',
          '📚  My things, out, not packed away',
          '🚪  I can close the door and it stays closed',
        ],
      ),
      PlannedQuestion(
        question: 'Who is there on an ordinary morning?',
        options: [
          '☕  Just me, and I like it',
          '💛  Someone I love, still asleep',
          '🐕  A dog who thinks it is time',
          '👨‍👩‍👧  Family, in and out all day',
        ],
      ),
      PlannedQuestion(
        question: 'How do you want to feel walking back in at night?',
        options: [
          '😌  Like I can finally exhale',
          '🥹  Proud, quietly, every time',
          '🕯️  Safe, and completely unbothered',
          '✨  Like the life I wanted started',
        ],
      ),
    ],
  );

  static const _homeScript = '''
Close your eyes. It is a Tuesday in October, and you are already awake before
the alarm.

The light is coming through the long window, the one you noticed the first time
you stood in this room and knew. It falls across the floor you chose. You lie
there for a minute and let it.

You get up. The kettle is where you put it, because you put it there. Nobody
else has moved it, and nobody is going to. You stand in your own kitchen in
your own quiet and wait for the water.

Sana, this is the part you did not expect. It is not the keys, and it is not
the day you signed. It is this: an ordinary morning, in a place that is yours,
and the complete absence of the feeling that you are borrowing it.

You take the cup to the window. Down there the city is starting. Up here it is
still yours for another ten minutes.

You are not waiting for this any more. You are in it.
''';

  static const _workScript = '''
Close your eyes. It is the end of the month, and you are looking at a number
you used to write down as a hope.

The transfer landed while you were making coffee. You checked it twice, the way
you always do, and then you sat down on the arm of the chair and let yourself
feel it properly.

Sana, this came from your own work. Not a raise somebody decided to give you.
Not a good month somebody else had. Yours.

You think about the version of you who priced the first job too low because
asking felt rude. She would not believe how ordinary this feels now.

You close the laptop. There is nothing to check. It is done, and it is going to
happen again next month.
''';

  static const _loveScript = '''
Close your eyes. It is a Sunday, late morning, and neither of you has any
reason to get up.

You are talking about nothing. The kind of nothing that takes an hour. At some
point you realise you have stopped performing — no version of yourself being
held up for inspection, just you, in the room, being liked.

Sana, this is what you were actually asking for. Not the story about it. This.

Later you will go out and get something to eat and it will not be an occasion,
because there are going to be a lot of these.

You are not looking any more. You have been found, and so have they.
''';

  static const _runScript = '''
Close your eyes. It is early, cold enough for gloves, and you are three
kilometres in without noticing.

Your breath found its rhythm somewhere back at the bridge. Your legs are
working. Nothing hurts in the way it used to hurt.

Sana, you did not become a different person. You just kept going out. The body
you are running in is the same one that could not do this in March, and it
learned because you asked it to, over and over, on mornings you did not want to.

The last stretch comes up. You do not slow down.

You finish, and you stand there with your hands on your head, laughing, because
you did the whole thing without stopping.
''';
}

/// Hands back [Demo.plan] instead of calling the server.
///
/// The four-questions screen is one network call away from working offline, and
/// this is that call. Subclassed rather than faked with a mock package because
/// there is one method to replace and the real class already has the shape.
class DemoPlanService implements PlanService {
  const DemoPlanService();

  @override
  Future<QuestionPlan> forDesire(String desire) async {
    // Long enough to see the orb turning, short enough not to sit through.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return Demo.plan;
  }
}

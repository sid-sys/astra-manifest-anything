import 'intention.dart';

/// Everything onboarding asks, kept in one place and sent with every story.
///
/// This is the middle layer of the three the app is built on: the core desire
/// stays put, these preferences stay put, and only "today's moment" changes.
/// The generator combines all three, which is what stops a daily story from
/// being either a re-run or a form to fill in every morning.
///
/// Every field is optional in the sense that a missing answer means the story
/// simply does not lean on it. Nothing here is inferred — a blank is a blank,
/// never a guess, for the same reason the app asks for gender rather than
/// reading it off a name.

/// What the desire is about.
///
/// Ten of these where [Intention] has six, because these are the words a user
/// picks from and those are the axis the rest of the app is built on —
/// affirmations, the library filter, the daily card. Each one maps onto an
/// intention rather than replacing it, so adding a category never leaves a
/// screen elsewhere with nothing to show.
enum DesireCategory {
  love('Love & relationships', '❤️', Intention.love),
  health('Health & fitness', '💪', Intention.health),
  money('Money & financial freedom', '💰', Intention.abundance),
  career('Career & business', '💼', Intention.career),
  studies('Studies & exams', '📚', Intention.career),
  home('Home & lifestyle', '🏠', Intention.peace),
  travel('Travel & experiences', '✈️', Intention.peace),
  growth('Personal growth', '🌱', Intention.confidence),
  family('Family & relationships', '👨‍👩‍👧', Intention.love),
  other('Something else', '⭐', Intention.confidence);

  const DesireCategory(this.label, this.glyph, this.intention);

  final String label;
  final String glyph;

  /// The internal life area this belongs to.
  final Intention intention;

  static DesireCategory fromName(String? name) => DesireCategory.values
      .firstWhere((c) => c.name == name, orElse: () => DesireCategory.other);
}

/// When the user imagines it happening. Sets the date the story opens on.
enum Timeframe {
  month('Within 1 month', 30),
  threeMonths('Within 3 months', 90),
  sixMonths('Within 6 months', 180),
  year('Within 1 year', 365),
  years('In the next few years', 900),
  unsure('I don\'t know yet', 120);

  const Timeframe(this.label, this.days);

  final String label;

  /// Roughly how far ahead to set the scene. "I don't know yet" gets four
  /// months rather than nothing — a story with no date is a story with no
  /// specific moment, which is the one thing the style depends on.
  final int days;

  static Timeframe fromName(String? name) => Timeframe.values
      .firstWhere((t) => t.name == name, orElse: () => Timeframe.unsure);
}

/// Where the story happens.
enum StoryPlace {
  home('At home'),
  work('At work'),
  college('At college or school'),
  gym('At a gym or sports place'),
  cafe('At a café or restaurant'),
  outdoors('Outdoors'),
  trip('On a trip'),
  city('In my city'),
  elsewhere('Somewhere else');

  const StoryPlace(this.label);

  final String label;

  static StoryPlace fromName(String? name) => StoryPlace.values
      .firstWhere((p) => p.name == name, orElse: () => StoryPlace.home);
}

/// Who is in it. More than one may be chosen.
enum StoryCast {
  alone('Just me', ''),
  partner('My partner or crush', 'Their name'),
  family('My family', 'Names — Mom, Dad, Sarah'),
  friends('My friends', 'Names — Jake, Emma'),
  colleagues('My colleagues', 'Names — Chris, my manager Priya'),
  someone('A specific person', 'The name you would actually use');

  const StoryCast(this.label, this.nameHint);

  final String label;

  /// What to put in the optional name box for this group. Empty for [alone],
  /// which is the one choice with nobody to name.
  ///
  /// Names are what turn "I had dinner with my family" into a scene. The
  /// generator cannot invent them safely — an invented sister is a stranger in
  /// your own memory — so it either gets the real ones or writes around them.
  final String nameHint;

  bool get takesNames => this != StoryCast.alone;

  static StoryCast fromName(String? name) => StoryCast.values
      .firstWhere((c) => c.name == name, orElse: () => StoryCast.alone);
}

/// How it should feel when the desire is real. Up to three.
enum Feeling {
  happy('Happy', '😊'),
  loved('Loved', '❤️'),
  peaceful('Peaceful', '😌'),
  confident('Confident', '💪'),
  moved('Emotional', '🥹'),
  proud('Proud', '🏆'),
  excited('Excited', '🔥'),
  secure('Secure', '💰'),
  successful('Successful', '🌟'),
  free('Free', '🦋');

  const Feeling(this.label, this.glyph);

  final String label;
  final String glyph;

  static Feeling fromName(String? name) => Feeling.values
      .firstWhere((f) => f.name == name, orElse: () => Feeling.happy);
}

/// How much of the user's life has changed by the time the story happens.
enum FutureShape {
  oneThing('Things are mostly the same, but this one thing has changed'),
  improved('My daily life has noticeably improved'),
  transformed('My life feels completely different'),
  surprise('I\'m not sure, surprise me');

  const FutureShape(this.label);

  final String label;

  static FutureShape fromName(String? name) => FutureShape.values
      .firstWhere((s) => s.name == name, orElse: () => FutureShape.improved);
}

/// The register the story is written in.
enum StoryStyle {
  simple('Short and simple'),
  detailed('Realistic and detailed'),
  heartfelt('Emotional and heartfelt'),
  romantic('Romantic and intimate'),
  motivational('Motivational and powerful'),
  calm('Calm and peaceful'),
  surprise('Surprise me');

  const StoryStyle(this.label);

  final String label;

  static StoryStyle fromName(String? name) => StoryStyle.values
      .firstWhere((s) => s.name == name, orElse: () => StoryStyle.detailed);
}

/// How close to ordinary life it should stay.
enum Realism {
  tomorrow('Very realistic, like something that could happen tomorrow'),
  slightlyMagical('Realistic, but a little magical'),
  dreamy('Dreamy and exciting'),
  memory('Like a real memory from my future');

  const Realism(this.label);

  final String label;

  static Realism fromName(String? name) => Realism.values
      .firstWhere((r) => r.name == name, orElse: () => Realism.tomorrow);
}

/// What has to feel true for the story to land.
///
/// The most useful answer in the set, because it tells the generator which
/// kind of specificity to spend its words on. Someone who says "the
/// conversations" wants dialogue; someone who says "the little everyday
/// details" wants the coffee going cold.
enum Authenticity {
  people('The people feel real'),
  conversations('The conversations feel real'),
  location('The location feels real'),
  emotions('My emotions feel real'),
  details('The little everyday details'),
  everything('Everything'),
  surprise('I don\'t know, surprise me');

  const Authenticity(this.label);

  final String label;

  static Authenticity fromName(String? name) => Authenticity.values
      .firstWhere((a) => a.name == name, orElse: () => Authenticity.everything);
}

/// The answers, together.
class StoryPreferences {
  const StoryPreferences({
    this.category = DesireCategory.other,
    this.desire = '',
    this.timeframe = Timeframe.unsure,
    this.place = StoryPlace.home,
    this.placeDetail = '',
    this.cast = const {StoryCast.alone},
    this.castNames = const {},
    // Opens already answered, like the seven single-choice questions do.
    // "How do you want to feel when it is real" is compulsory, and a
    // compulsory question that starts empty is a wall — every other required
    // question in the flow either has a default or is a box you were always
    // going to type in. Happy is the safe opening guess: it is true of very
    // nearly every desire anyone brings here, and it is one tap to change.
    this.feelings = const {Feeling.happy},
    this.futureShape = FutureShape.improved,
    this.style = StoryStyle.detailed,
    this.realism = Realism.tomorrow,
    this.extras = '',
    this.authenticity = Authenticity.everything,
  });

  final DesireCategory category;

  /// The core desire, in the user's own words. The single most load-bearing
  /// string in the app.
  final String desire;

  final Timeframe timeframe;
  final StoryPlace place;

  /// A city or a named place, free text. "Kochi" is what turns a café into
  /// somewhere the reader has actually stood.
  final String placeDetail;

  final Set<StoryCast> cast;

  /// Who those people actually are, keyed by [StoryCast.name].
  ///
  /// Optional everywhere, and only asked for the groups that were chosen. A
  /// story about "my friends" is about nobody; a story where Jake is late
  /// again is about a Tuesday you remember. The value is free text rather than
  /// a list because "my sister Emma and her husband" is how people answer.
  ///
  /// Names are all that is asked, deliberately. Gender is never collected for
  /// anyone here and never inferred from a name — the stories use the name
  /// itself wherever a pronoun would otherwise go, which is enforced in the
  /// system prompt rather than worked around here.
  final Map<String, String> castNames;

  /// The name given for [StoryCast.someone].
  ///
  /// A getter rather than a field since [castNames] arrived. It is still
  /// written to storage under its old key and still read by the server, which
  /// repeats the no-gender rule beside it.
  String get personName => castNames[StoryCast.someone.name] ?? '';

  /// The name box for one group, empty when it was skipped.
  String nameFor(StoryCast who) => castNames[who.name] ?? '';

  final Set<Feeling> feelings;
  final FutureShape futureShape;
  final StoryStyle style;
  final Realism realism;

  /// Anything the user wants written in: a sentence someone says, a song, a
  /// date, an object.
  final String extras;

  final Authenticity authenticity;

  static const empty = StoryPreferences();

  /// True once there is enough here to write from.
  bool get isComplete => desire.trim().isNotEmpty;

  StoryPreferences copyWith({
    DesireCategory? category,
    String? desire,
    Timeframe? timeframe,
    StoryPlace? place,
    String? placeDetail,
    Set<StoryCast>? cast,
    Map<String, String>? castNames,
    Set<Feeling>? feelings,
    FutureShape? futureShape,
    StoryStyle? style,
    Realism? realism,
    String? extras,
    Authenticity? authenticity,
  }) => StoryPreferences(
    category: category ?? this.category,
    desire: desire ?? this.desire,
    timeframe: timeframe ?? this.timeframe,
    place: place ?? this.place,
    placeDetail: placeDetail ?? this.placeDetail,
    cast: cast ?? this.cast,
    castNames: castNames ?? this.castNames,
    feelings: feelings ?? this.feelings,
    futureShape: futureShape ?? this.futureShape,
    style: style ?? this.style,
    realism: realism ?? this.realism,
    extras: extras ?? this.extras,
    authenticity: authenticity ?? this.authenticity,
  );

  Map<String, dynamic> toMap() => {
    'category': category.name,
    'desire': desire,
    'timeframe': timeframe.name,
    'place': place.name,
    'placeDetail': placeDetail,
    'cast': cast.map((c) => c.name).toList(),
    'castNames': castNames,
    // Written as well as `castNames`, because the server reads this key and an
    // app that stopped writing it would quietly drop the one name the no-gender
    // rule is repeated for.
    'personName': personName,
    'feelings': feelings.map((f) => f.name).toList(),
    'futureShape': futureShape.name,
    'style': style.name,
    'realism': realism.name,
    'extras': extras,
    'authenticity': authenticity.name,
  };

  factory StoryPreferences.fromMap(Map<String, dynamic> map) =>
      StoryPreferences(
        category: DesireCategory.fromName(map['category'] as String?),
        desire: map['desire'] as String? ?? '',
        timeframe: Timeframe.fromName(map['timeframe'] as String?),
        place: StoryPlace.fromName(map['place'] as String?),
        placeDetail: map['placeDetail'] as String? ?? '',
        cast: ((map['cast'] as List?) ?? const [])
            .map((n) => StoryCast.fromName(n as String))
            .toSet(),
        castNames: _readCastNames(map),
        feelings: ((map['feelings'] as List?) ?? const [])
            .map((n) => Feeling.fromName(n as String))
            .toSet(),
        futureShape: FutureShape.fromName(map['futureShape'] as String?),
        style: StoryStyle.fromName(map['style'] as String?),
        realism: Realism.fromName(map['realism'] as String?),
        extras: map['extras'] as String? ?? '',
        authenticity: Authenticity.fromName(map['authenticity'] as String?),
      );

  /// Reads the names, taking the old single-name key with it.
  ///
  /// Profiles written before the other groups could be named have only
  /// `personName`. Dropping it would have silently deleted the one name those
  /// accounts had given, so it is folded in as the name for "a specific
  /// person" — which is exactly what it was.
  static Map<String, String> _readCastNames(Map<String, dynamic> map) {
    final names = <String, String>{};

    final stored = map['castNames'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        final value = (entry.value as String? ?? '').trim();
        if (value.isNotEmpty) names[entry.key as String] = value;
      }
    }

    final legacy = (map['personName'] as String? ?? '').trim();
    if (legacy.isNotEmpty) {
      names.putIfAbsent(StoryCast.someone.name, () => legacy);
    }

    return names;
  }
}

/// What today's story should be about. Chosen on Home, not in onboarding.
enum StoryFocus {
  desire('My desire', 'Continue the main storyline'),
  fresh('Something new', 'A different part of the same life'),
  surprise('Surprise me', 'Mayow picks the moment');

  const StoryFocus(this.label, this.detail);

  final String label;
  final String detail;

  static StoryFocus fromName(String? name) => StoryFocus.values
      .firstWhere((f) => f.name == name, orElse: () => StoryFocus.desire);
}

/// One onboarding answer, offered as something to write a manifestation from.
///
/// The [key] is the wire name the server filters on, and it has to match the
/// keys in `PREFERENCE_KEYS` in `functions/index.js`. The [label] is what the
/// chip says — short, because nine of them sit in one wrap.
class ManifestFactor {
  const ManifestFactor(this.key, this.label, this.value);

  final String key;
  final String label;

  /// The answer itself, in the words the user would recognise.
  ///
  /// Shown beside the switch, because "Place" tells somebody nothing about
  /// whether they want it used — "Place · at home" tells them everything.
  final String value;

  /// The answers this profile actually gave, in the order they were asked.
  ///
  /// Only what produces something. A chip for an answer that adds no line to
  /// the brief is a control that does nothing, which is worse than a missing
  /// one — the extras box is usually empty, and the place detail usually is
  /// too.
  static List<ManifestFactor> from(StoryPreferences p) => [
    ManifestFactor('timeframe', 'Timeframe', p.timeframe.label),
    if (p.cast.isNotEmpty)
      ManifestFactor(
        'cast',
        'People',
        p.cast.map((who) => who.label).join(', '),
      ),
    ManifestFactor('place', 'Place', p.place.label),
  ];

  /// Every key, which is what "use all my answers" means.
  static Set<String> allKeys(StoryPreferences p) =>
      {for (final factor in from(p)) factor.key};
}

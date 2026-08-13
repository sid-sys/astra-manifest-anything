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
  alone('Just me'),
  partner('My partner or crush'),
  family('My family'),
  friends('My friends'),
  colleagues('My colleagues'),
  someone('A specific person');

  const StoryCast(this.label);

  final String label;

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
    this.personName = '',
    this.personGender = '',
    this.feelings = const {},
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

  /// Only meaningful when [cast] includes [StoryCast.someone].
  final String personName;

  /// Their gender, if the user says so — and blank otherwise.
  ///
  /// Asked because not asking did not work. The system prompt forbids
  /// inventing a gender for anyone named in the brief, and a live generation
  /// broke that rule thirty-eight times in one story: given "Abhirami" and a
  /// romantic style, the model simply decided. A rule the writer can overrule
  /// is not a rule, and the only reliable fix for "do not guess" is to know.
  ///
  /// Blank still means blank. The brief omits the line, and the prompt's
  /// instruction to lean on the person's name rather than a pronoun stands.
  final String personGender;

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
    String? personName,
    String? personGender,
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
    personName: personName ?? this.personName,
    personGender: personGender ?? this.personGender,
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
    'personName': personName,
    'personGender': personGender,
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
        personName: map['personName'] as String? ?? '',
        personGender: map['personGender'] as String? ?? '',
        feelings: ((map['feelings'] as List?) ?? const [])
            .map((n) => Feeling.fromName(n as String))
            .toSet(),
        futureShape: FutureShape.fromName(map['futureShape'] as String?),
        style: StoryStyle.fromName(map['style'] as String?),
        realism: Realism.fromName(map['realism'] as String?),
        extras: map['extras'] as String? ?? '',
        authenticity: Authenticity.fromName(map['authenticity'] as String?),
      );
}

/// What today's story should be about. Chosen on Home, not in onboarding.
enum StoryFocus {
  desire('My desire', 'Continue the main storyline'),
  fresh('Something new', 'A different part of the same life'),
  surprise('Surprise me', 'Astra picks the moment');

  const StoryFocus(this.label, this.detail);

  final String label;
  final String detail;

  static StoryFocus fromName(String? name) => StoryFocus.values
      .firstWhere((f) => f.name == name, orElse: () => StoryFocus.desire);
}

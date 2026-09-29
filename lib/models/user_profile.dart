import 'intention.dart';
import 'plan.dart';
import 'story_preferences.dart';

/// Everything the story generator needs to write in the user's own life.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.intentions,
    required this.aspiration,
    required this.voice,
    required this.joinedAt,
    this.remindersOn = false,
    this.reminderHour = 7,
    this.reminderMinute = 0,
    this.eveningHour = 22,
    this.eveningMinute = 0,
    this.fcmToken,
    this.timezone,
    this.preferences = StoryPreferences.empty,
    this.age,
    this.gender = '',
    this.isSubscribed = false,
    this.subscribedAt,
    this.paywallSeen = false,
    this.firstStoryStarted = false,
    this.onboardingDone = false,
    this.belief = '',
    this.importance = '',
    this.reminderPref = '',
    this.onboardingV2Done = false,
    this.sendMorning = true,
    this.sendEvening = true,
  });

  final String name;
  final Set<Intention> intentions;

  /// Daily affirmation reminder. Off until someone turns it on — an app that
  /// starts notifying you before you asked is an app whose notifications get
  /// switched off at the system level, permanently.
  final bool remindersOn;
  final int reminderHour;
  final int reminderMinute;

  /// The second send, in the user's own time. Ten at night by default.
  ///
  /// Two a day rather than one, because that is when an affirmation is
  /// actually said: on waking, before the day has had an opinion, and before
  /// sleep. Both are changeable; neither has to be.
  final int eveningHour;
  final int eveningMinute;

  /// Where to push this user's affirmation, and the zone that decides when.
  ///
  /// Both are mirrored to Firestore because the scheduled function is the one
  /// that reads them — it has no other way to know that eight in the morning is
  /// half past two UTC for this particular phone. Null when reminders are off,
  /// which is also how the sender knows to skip the account rather than push
  /// into a dead address.
  ///
  /// The zone is an IANA name ("Asia/Kolkata"), never an offset: an offset
  /// stored once is wrong twice a year for anyone who observes daylight saving,
  /// and arriving in the morning is the entire point.
  final String? fcmToken;
  final String? timezone;

  /// Optional, and stated rather than inferred. The story generator writes in
  /// the listener's own voice, so knowing "27, female" lets it write a life
  /// that fits — but both fields can be skipped, and an empty value means the
  /// stories simply never mention it. Nothing in the app guesses either one.
  final int? age;
  final String gender;

  /// The user's goal in their own words — the raw material that makes a story
  /// feel specific rather than generic.
  ///
  /// Kept alongside [preferences] rather than replaced by it, because it is
  /// what every profile written before onboarding started asking these
  /// questions has. [StoryPreferences.desire] is the same sentence for anyone
  /// who has onboarded since; `preferences.desire` wins when both exist.
  final String aspiration;

  /// Everything onboarding asked, sent with every story.
  ///
  /// The second of the three layers the generator combines: a core desire that
  /// stays put, preferences that stay put, and today's moment, which is the
  /// only thing the user types again.
  final StoryPreferences preferences;
  final String voice;
  final DateTime joinedAt;
  final bool isSubscribed;

  /// When the subscription started.
  ///
  /// The monthly allowance is counted from this date, not from the first of
  /// the month, because a story written before anyone paid is not something
  /// they paid for. Without it, subscribing on the 20th silently handed over
  /// an allowance already spent by the free tier.
  final DateTime? subscribedAt;

  /// Whether the subscription screen has been shown once after onboarding.
  final bool paywallSeen;

  /// Whether the automatic first story has already been attempted.
  ///
  /// Set before the attempt rather than after, so a generation that fails —
  /// or an app killed mid-write — does not re-fire it on every launch. Each
  /// story costs real money; "did we try" is the honest question here, not
  /// "did it work". The user can always press the button themselves.
  final bool firstStoryStarted;

  /// Whether the questions were answered through to the end.
  ///
  /// A real field, because the thing that used to stand in for one is gone.
  /// "Onboarded" meant "has a desire", since the desire was question three and
  /// nothing else was compulsory enough to test. The desire is now typed on
  /// Home for each manifestation rather than answered once, so that test would
  /// send every existing user back through the questions on their next launch.
  ///
  /// [isOnboarded] still accepts the old evidence as well, so nobody who
  /// answered under the previous flow is asked again.
  final bool onboardingDone;

  /// How strongly this person believes their thoughts can shape their life —
  /// one of "absolutely", "i-think-so", "not-sure", "not-really". Asked first
  /// in the belief-and-ritual onboarding, never shown back to them; it colours
  /// how confidently Maya writes rather than being quoted at them.
  final String belief;

  /// How much they want the change they named — one of "not-sure",
  /// "would-like-it", "very-important", "ready-to-change".
  final String importance;

  /// When they want reminders — "morning", "evening", "both" or "later". Feeds
  /// [remindersOn] and the two send times rather than replacing them; this is
  /// the answer that decided what those started as.
  final String reminderPref;

  /// Whether the belief-and-ritual onboarding (four questions, not the old
  /// twelve) has been completed.
  ///
  /// Deliberately separate from [onboardingDone]: that flag is satisfied by
  /// almost every existing account already (a name typed at signup is enough),
  /// which would skip this newer flow for everyone who has ever used the app.
  /// This one only a real answer to these four questions can set.
  final bool onboardingV2Done;

  /// Which of the two daily sends this account gets, given [remindersOn].
  ///
  /// True for both by default so every account that predates these fields —
  /// which is every account, since they came with the reminder-timing
  /// onboarding question — keeps getting exactly what it always got. Only the
  /// onboarding question or a deliberate change in Profile turns either one
  /// off; [remindersOn] itself stays the master switch for "any reminders at
  /// all", so turning it off still silences both without touching these.
  final bool sendMorning;
  final bool sendEvening;

  static UserProfile empty() => UserProfile(
    name: '',
    intentions: const {},
    aspiration: '',
    voice: 'marin',
    joinedAt: DateTime.now(),
  );

  /// Whether onboarding has been answered.
  ///
  /// The desire alone, because it is the only answer onboarding insists on.
  /// This used to require a name too, which stopped being true the moment the
  /// name question was removed — and would have left every new user stuck on
  /// the onboarding screen forever, having just answered four questions.
  ///
  /// [aspiration] is checked as well so profiles written before the questions
  /// changed still read as onboarded rather than being asked everything again.
  bool get isOnboarded =>
      name.trim().isNotEmpty ||
      onboardingDone ||
      // Written before [onboardingDone] existed. Both were set by finishing the
      // questions, so either one proves it.
      preferences.desire.trim().isNotEmpty ||
      aspiration.trim().isNotEmpty;

  /// Whether a story can be written without paying, given how many have been
  /// written already.
  ///
  /// The first [PricingCatalog.freeStories] are free for everyone, with no
  /// clock and no card. That is the whole answer to the app this one is
  /// modelled on, which asks for money before anyone has heard anything — you
  /// cannot judge a generated story from a description of it.
  ///
  /// Advisory only. The server counts the same stories and is the copy that
  /// decides, because a limit a device can reset by clearing its storage is
  /// not a limit.
  bool canGenerate({required int storiesWritten}) =>
      isSubscribed || storiesWritten < PricingCatalog.freeStories;

  UserProfile copyWith({
    String? name,
    Set<Intention>? intentions,
    String? aspiration,
    StoryPreferences? preferences,
    String? voice,
    int? age,
    String? gender,
    bool? remindersOn,
    int? reminderHour,
    int? reminderMinute,
    int? eveningHour,
    int? eveningMinute,
    String? fcmToken,
    String? timezone,
    bool? isSubscribed,
    DateTime? subscribedAt,
    bool? paywallSeen,
    bool? firstStoryStarted,
    bool? onboardingDone,
    String? belief,
    String? importance,
    String? reminderPref,
    bool? onboardingV2Done,
    bool? sendMorning,
    bool? sendEvening,
    bool clearPush = false,
  }) => UserProfile(
    name: name ?? this.name,
    intentions: intentions ?? this.intentions,
    aspiration: aspiration ?? this.aspiration,
    preferences: preferences ?? this.preferences,
    voice: voice ?? this.voice,
    age: age ?? this.age,
    remindersOn: remindersOn ?? this.remindersOn,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    eveningHour: eveningHour ?? this.eveningHour,
    eveningMinute: eveningMinute ?? this.eveningMinute,
    // Erasable, unlike every other field here. Turning reminders off has to be
    // able to clear the token, and `??` can only ever keep the old one — a
    // "deleted" push address that still sits in Firestore is one the sender
    // would happily keep using.
    fcmToken: clearPush ? null : (fcmToken ?? this.fcmToken),
    timezone: clearPush ? null : (timezone ?? this.timezone),
    gender: gender ?? this.gender,
    joinedAt: joinedAt,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    paywallSeen: paywallSeen ?? this.paywallSeen,
    firstStoryStarted: firstStoryStarted ?? this.firstStoryStarted,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    belief: belief ?? this.belief,
    importance: importance ?? this.importance,
    reminderPref: reminderPref ?? this.reminderPref,
    onboardingV2Done: onboardingV2Done ?? this.onboardingV2Done,
    sendMorning: sendMorning ?? this.sendMorning,
    sendEvening: sendEvening ?? this.sendEvening,
  );

  /// Only what the app uses today. The old onboarding answers (age, gender,
  /// aspiration, story preferences, voice, progress flags) are no longer asked
  /// or written; the admin panel can remove them from older accounts.
  Map<String, dynamic> toMap() => {
    'name': name,
    'intentions': intentions.map((i) => i.name).toList(),
    'remindersOn': remindersOn,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'eveningHour': eveningHour,
    'eveningMinute': eveningMinute,
    'fcmToken': fcmToken,
    'timezone': timezone,
    'joinedAt': joinedAt.toIso8601String(),
    'isSubscribed': isSubscribed,
    'subscribedAt': subscribedAt?.toIso8601String(),
    'belief': belief,
    'importance': importance,
    'reminderPref': reminderPref,
    'onboardingV2Done': onboardingV2Done,
    'sendMorning': sendMorning,
    'sendEvening': sendEvening,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    name: map['name'] as String? ?? '',
    intentions: ((map['intentions'] as List?) ?? const [])
        .map((n) => Intention.fromName(n as String))
        .toSet(),
    aspiration: map['aspiration'] as String? ?? '',
    preferences: map['preferences'] == null
        ? StoryPreferences.empty
        : StoryPreferences.fromMap(
            Map<String, dynamic>.from(map['preferences'] as Map),
          ),
    voice: map['voice'] as String? ?? 'marin',
    age: (map['age'] as num?)?.toInt(),
    remindersOn: map['remindersOn'] as bool? ?? false,
    reminderHour: (map['reminderHour'] as num?)?.toInt() ?? 8,
    reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? 0,
    fcmToken: map['fcmToken'] as String?,
    timezone: map['timezone'] as String?,
    gender: map['gender'] as String? ?? '',
    joinedAt:
        DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    isSubscribed: map['isSubscribed'] as bool? ?? false,
    subscribedAt: DateTime.tryParse(map['subscribedAt'] as String? ?? ''),
    paywallSeen: map['paywallSeen'] as bool? ?? false,
    firstStoryStarted: map['firstStoryStarted'] as bool? ?? false,
    onboardingDone: map['onboardingDone'] as bool? ?? false,
    belief: map['belief'] as String? ?? '',
    importance: map['importance'] as String? ?? '',
    reminderPref: map['reminderPref'] as String? ?? '',
    onboardingV2Done: map['onboardingV2Done'] as bool? ?? false,
    sendMorning: map['sendMorning'] as bool? ?? true,
    sendEvening: map['sendEvening'] as bool? ?? true,
  );
}

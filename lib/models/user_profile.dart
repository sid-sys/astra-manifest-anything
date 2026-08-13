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
    this.reminderHour = 8,
    this.reminderMinute = 0,
    this.fcmToken,
    this.timezone,
    this.preferences = StoryPreferences.empty,
    this.age,
    this.gender = '',
    this.isSubscribed = false,
    this.subscribedAt,
    this.paywallSeen = false,
  });

  final String name;
  final Set<Intention> intentions;

  /// Daily affirmation reminder. Off until someone turns it on — an app that
  /// starts notifying you before you asked is an app whose notifications get
  /// switched off at the system level, permanently.
  final bool remindersOn;
  final int reminderHour;
  final int reminderMinute;

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
  /// the onboarding screen forever, having just answered eleven questions.
  ///
  /// [aspiration] is checked as well so profiles written before the questions
  /// changed still read as onboarded rather than being asked everything again.
  bool get isOnboarded =>
      preferences.desire.trim().isNotEmpty || aspiration.trim().isNotEmpty;

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
    String? fcmToken,
    String? timezone,
    bool? isSubscribed,
    DateTime? subscribedAt,
    bool? paywallSeen,
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
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'intentions': intentions.map((i) => i.name).toList(),
    'aspiration': aspiration,
    'preferences': preferences.toMap(),
    'voice': voice,
    'age': age,
    'remindersOn': remindersOn,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'fcmToken': fcmToken,
    'timezone': timezone,
    'gender': gender,
    'joinedAt': joinedAt.toIso8601String(),
    'isSubscribed': isSubscribed,
    'subscribedAt': subscribedAt?.toIso8601String(),
    'paywallSeen': paywallSeen,
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
  );
}

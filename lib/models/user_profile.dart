import 'intention.dart';
import 'plan.dart';

/// Everything the story generator needs to write in the user's own life.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.intentions,
    required this.aspiration,
    required this.voice,
    required this.joinedAt,
    this.age,
    this.gender = '',
    this.isSubscribed = false,
    this.subscribedAt,
    this.paywallSeen = false,
  });

  final String name;
  final Set<Intention> intentions;

  /// Optional, and stated rather than inferred. The story generator writes in
  /// the listener's own voice, so knowing "27, female" lets it write a life
  /// that fits — but both fields can be skipped, and an empty value means the
  /// stories simply never mention it. Nothing in the app guesses either one.
  final int? age;
  final String gender;

  /// The user's goal in their own words — the raw material that makes a story
  /// feel specific rather than generic.
  final String aspiration;
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

  bool get isOnboarded => name.isNotEmpty && intentions.isNotEmpty;

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
    String? voice,
    int? age,
    String? gender,
    bool? isSubscribed,
    DateTime? subscribedAt,
    bool? paywallSeen,
  }) => UserProfile(
    name: name ?? this.name,
    intentions: intentions ?? this.intentions,
    aspiration: aspiration ?? this.aspiration,
    voice: voice ?? this.voice,
    age: age ?? this.age,
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
    'voice': voice,
    'age': age,
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
    voice: map['voice'] as String? ?? 'marin',
    age: (map['age'] as num?)?.toInt(),
    gender: map['gender'] as String? ?? '',
    joinedAt:
        DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    isSubscribed: map['isSubscribed'] as bool? ?? false,
    subscribedAt: DateTime.tryParse(map['subscribedAt'] as String? ?? ''),
    paywallSeen: map['paywallSeen'] as bool? ?? false,
  );
}

import 'intention.dart';

/// Everything the story generator needs to write in the user's own life.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.intentions,
    required this.aspiration,
    required this.voice,
    required this.joinedAt,
    this.isSubscribed = false,
    this.subscribedAt,
    this.trialStartedAt,
    this.paywallSeen = false,
  });

  final String name;
  final Set<Intention> intentions;

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

  /// When the free day began. Null means it has not been started.
  ///
  /// The user starts it deliberately, from the paywall. It used to start itself
  /// on the first generation, which meant the clock was already running before
  /// anyone had been told there was one — a free day nobody knows about is not
  /// an offer, it is an expiry.
  final DateTime? trialStartedAt;

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

  /// Whether the free day has been started at all.
  bool get trialStarted => trialStartedAt != null;

  /// Whether the free day is still running. Advisory only — the server holds
  /// the authoritative clock, because a limit a device can reset by clearing
  /// its storage is not a limit.
  bool get trialActive {
    if (trialStartedAt == null) return false;
    return DateTime.now().difference(trialStartedAt!) < const Duration(hours: 24);
  }

  Duration get trialRemaining {
    if (trialStartedAt == null) return const Duration(hours: 24);
    final left =
        const Duration(hours: 24) - DateTime.now().difference(trialStartedAt!);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether a story can be written without paying, given how many have been
  /// written already.
  ///
  /// The first story is free for everyone, with no trial started and no card
  /// asked for. It is the whole answer to the app this one is modelled on,
  /// which asks for money before anyone has heard anything — you cannot judge
  /// a generated story from a description of it.
  bool canGenerate({required int storiesWritten}) =>
      isSubscribed || storiesWritten == 0 || trialActive;

  UserProfile copyWith({
    String? name,
    Set<Intention>? intentions,
    String? aspiration,
    String? voice,
    bool? isSubscribed,
    DateTime? subscribedAt,
    DateTime? trialStartedAt,
    bool? paywallSeen,
  }) => UserProfile(
    name: name ?? this.name,
    intentions: intentions ?? this.intentions,
    aspiration: aspiration ?? this.aspiration,
    voice: voice ?? this.voice,
    joinedAt: joinedAt,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    trialStartedAt: trialStartedAt ?? this.trialStartedAt,
    paywallSeen: paywallSeen ?? this.paywallSeen,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'intentions': intentions.map((i) => i.name).toList(),
    'aspiration': aspiration,
    'voice': voice,
    'joinedAt': joinedAt.toIso8601String(),
    'isSubscribed': isSubscribed,
    'subscribedAt': subscribedAt?.toIso8601String(),
    'trialStartedAt': trialStartedAt?.toIso8601String(),
    'paywallSeen': paywallSeen,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    name: map['name'] as String? ?? '',
    intentions: ((map['intentions'] as List?) ?? const [])
        .map((n) => Intention.fromName(n as String))
        .toSet(),
    aspiration: map['aspiration'] as String? ?? '',
    voice: map['voice'] as String? ?? 'marin',
    joinedAt:
        DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    isSubscribed: map['isSubscribed'] as bool? ?? false,
    subscribedAt: DateTime.tryParse(map['subscribedAt'] as String? ?? ''),
    trialStartedAt: DateTime.tryParse(map['trialStartedAt'] as String? ?? ''),
    paywallSeen: map['paywallSeen'] as bool? ?? false,
  );
}

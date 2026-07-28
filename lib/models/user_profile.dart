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
    this.freeStoryUsed = false,
    this.reminderHour = 21,
    this.reminderMinute = 0,
    this.countryOverride,
  });

  final String name;
  final Set<Intention> intentions;

  /// The user's goal in their own words — the raw material that makes a story
  /// feel specific rather than generic.
  final String aspiration;
  final String voice;
  final DateTime joinedAt;
  final bool isSubscribed;

  /// The free tier grants one complete story before the paywall is ever shown.
  final bool freeStoryUsed;
  final int reminderHour;
  final int reminderMinute;

  /// Set when the user picks a region manually in Settings.
  final String? countryOverride;

  static UserProfile empty() => UserProfile(
    name: '',
    intentions: const {},
    aspiration: '',
    voice: 'Meera',
    joinedAt: DateTime.now(),
  );

  bool get isOnboarded => name.isNotEmpty && intentions.isNotEmpty;

  bool get canGenerateFreely => isSubscribed || !freeStoryUsed;

  UserProfile copyWith({
    String? name,
    Set<Intention>? intentions,
    String? aspiration,
    String? voice,
    bool? isSubscribed,
    bool? freeStoryUsed,
    int? reminderHour,
    int? reminderMinute,
    String? countryOverride,
  }) => UserProfile(
    name: name ?? this.name,
    intentions: intentions ?? this.intentions,
    aspiration: aspiration ?? this.aspiration,
    voice: voice ?? this.voice,
    joinedAt: joinedAt,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    freeStoryUsed: freeStoryUsed ?? this.freeStoryUsed,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    countryOverride: countryOverride ?? this.countryOverride,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'intentions': intentions.map((i) => i.name).toList(),
    'aspiration': aspiration,
    'voice': voice,
    'joinedAt': joinedAt.toIso8601String(),
    'isSubscribed': isSubscribed,
    'freeStoryUsed': freeStoryUsed,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'countryOverride': countryOverride,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    name: map['name'] as String? ?? '',
    intentions: ((map['intentions'] as List?) ?? const [])
        .map((n) => Intention.fromName(n as String))
        .toSet(),
    aspiration: map['aspiration'] as String? ?? '',
    voice: map['voice'] as String? ?? 'Meera',
    joinedAt:
        DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    isSubscribed: map['isSubscribed'] as bool? ?? false,
    freeStoryUsed: map['freeStoryUsed'] as bool? ?? false,
    reminderHour: (map['reminderHour'] as num?)?.toInt() ?? 21,
    reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? 0,
    countryOverride: map['countryOverride'] as String?,
  );
}

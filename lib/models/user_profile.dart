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
    this.trialStartedAt,
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

  /// When the free day began, stamped by the server on the first generation.
  /// Null means the trial has not started yet.
  final DateTime? trialStartedAt;
  final int reminderHour;
  final int reminderMinute;

  /// Set when the user picks a region manually in Settings.
  final String? countryOverride;

  static UserProfile empty() => UserProfile(
    name: '',
    intentions: const {},
    aspiration: '',
    voice: 'marin',
    joinedAt: DateTime.now(),
  );

  bool get isOnboarded => name.isNotEmpty && intentions.isNotEmpty;

  /// Whether the free day is still running. Advisory only — the server holds
  /// the authoritative clock, because a limit a device can reset by clearing
  /// its storage is not a limit.
  bool get trialActive {
    if (trialStartedAt == null) return true;
    return DateTime.now().difference(trialStartedAt!) < const Duration(hours: 24);
  }

  bool get canGenerateFreely => isSubscribed || trialActive;

  UserProfile copyWith({
    String? name,
    Set<Intention>? intentions,
    String? aspiration,
    String? voice,
    bool? isSubscribed,
    DateTime? trialStartedAt,
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
    trialStartedAt: trialStartedAt ?? this.trialStartedAt,
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
    'trialStartedAt': trialStartedAt?.toIso8601String(),
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
    voice: map['voice'] as String? ?? 'marin',
    joinedAt:
        DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    isSubscribed: map['isSubscribed'] as bool? ?? false,
    trialStartedAt: DateTime.tryParse(map['trialStartedAt'] as String? ?? ''),
    reminderHour: (map['reminderHour'] as num?)?.toInt() ?? 21,
    reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? 0,
    countryOverride: map['countryOverride'] as String?,
  );
}

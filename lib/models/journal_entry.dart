enum JournalKind {
  gratitude('gratitude'),
  evidence('evidence'),
  action('aligned action');

  const JournalKind(this.label);

  final String label;

  static JournalKind fromName(String name) => JournalKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => JournalKind.gratitude,
  );
}

/// An entry in the evidence log — the feature reviewers said the app this one
/// is modelled on was missing.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.body,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String body;
  final JournalKind kind;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'body': body,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory JournalEntry.fromMap(String id, Map<String, dynamic> map) =>
      JournalEntry(
        id: id,
        body: map['body'] as String? ?? '',
        kind: JournalKind.fromName(map['kind'] as String? ?? 'gratitude'),
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

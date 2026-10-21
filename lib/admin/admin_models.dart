/// The plan an account is on now. `none` is free, or a subscription that ended.
enum AdminPlan { none, monthly, yearly }

/// A plain-words title and an emoji for something the app reports.
({String emoji, String title}) describeEvent(String type) => switch (type) {
  'app_open' => (emoji: '👋', title: 'Opened the app'),
  'onboarding_start' => (emoji: '🚀', title: 'Started onboarding'),
  'onboarding_page' => (emoji: '📝', title: 'Answered a question'),
  'onboarding_done' => (emoji: '✅', title: 'Finished onboarding'),
  'wish_typed' => (emoji: '✍️', title: 'Typed a wish'),
  'paywall_view' => (emoji: '💳', title: 'Saw the paywall'),
  'paywall_close' => (emoji: '↩️', title: 'Closed the paywall'),
  'subscribe_tap' => (emoji: '🛒', title: 'Tried to pay'),
  'purchase_ok' => (emoji: '🎉', title: 'Subscribed'),
  'purchase_cancelled' => (emoji: '🚫', title: 'Cancelled the payment'),
  'purchase_failed' => (emoji: '⚠️', title: 'Payment failed'),
  'restore_tap' => (emoji: '🔁', title: 'Tried to restore a purchase'),
  'generate_start' => (emoji: '⏳', title: 'Asked for a manifestation'),
  'generate_ok' => (emoji: '🌙', title: 'Got a manifestation'),
  'generate_failed' => (emoji: '⚠️', title: 'Generation failed'),
  _ => (emoji: '•', title: type),
};

/// One thing a person did.
class AdminEvent {
  const AdminEvent({required this.time, required this.type, this.detail = ''});

  final DateTime time;
  final String type;
  final String detail;
}

/// One payment, in dollars. Estimated from the plan: see the repository.
class AdminPayment {
  const AdminPayment({required this.time, required this.amount});

  final DateTime time;
  final double amount;
}

/// A payment that did not go through, and why.
class PayFailure {
  const PayFailure({required this.time, required this.kind, required this.detail});

  final DateTime time;

  /// `cancelled`, `failed` or `unavailable`.
  final String kind;
  final String detail;
}

/// One phone that has the app.
class AdminDevice {
  const AdminDevice({
    required this.id,
    required this.ownerUid,
    required this.installedAt,
    required this.uninstalledAt,
    required this.lastSeenAt,
  });

  final String id;

  /// The account that last signed in on this phone.
  final String? ownerUid;
  final DateTime? installedAt;
  final DateTime? uninstalledAt;
  final DateTime? lastSeenAt;
}

/// One person, as the admin panel sees them.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.country,
    required this.joinedAt,
    required this.lastSeen,
    required this.isGuest,
    required this.plan,
    required this.everSubscribed,
    required this.subscribedAt,
    required this.expiryTime,
    required this.testPurchase,
    required this.onboardingSeconds,
    required this.onboardingComplete,
    required this.heardFrom,
    required this.answers,
    required this.steps,
    required this.openDays,
    required this.events,
    required this.payFailures,
    required this.paywallViews,
    required this.paymentAttempts,
    required this.typedWish,
    required this.payments,
    required this.manifestations,
    required this.affirmationSets,
    this.installedAt,
    this.uninstalledAt,
  });

  final String id;

  /// What they gave, or empty. Use [displayName] to show a person.
  final String name;
  final String email;
  final String country;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isGuest;

  final AdminPlan plan;
  final bool everSubscribed;
  final DateTime? subscribedAt;
  final DateTime? expiryTime;

  /// Play says the buyer is a licence tester.
  final bool testPurchase;

  /// How long onboarding took, if both ends were recorded.
  final int? onboardingSeconds;
  final bool onboardingComplete;

  /// `instagram`, `tiktok`, ... or empty when never asked.
  final String heardFrom;

  /// The onboarding answers: belief, importance, reminderPref, areas.
  final Map<String, Object?> answers;

  /// The first time each step happened: `app_open`, `onboarding_start`,
  /// `onboarding_page_1`..`5`, `onboarding_done`, `wish_typed`,
  /// `paywall_view`, `subscribe_tap`, `purchase_ok`.
  final Map<String, DateTime> steps;

  /// UTC dates (`2026-10-14`) on which the app was opened.
  final Set<String> openDays;

  /// Newest first.
  final List<AdminEvent> events;
  final List<PayFailure> payFailures;
  final int paywallViews;
  final int paymentAttempts;
  final bool typedWish;
  final List<AdminPayment> payments;

  /// When each manifestation and affirmation set was made, for the cost line.
  final List<DateTime> manifestations;
  final List<DateTime> affirmationSets;

  /// The first install and the last uninstall of the phones this person owns.
  final DateTime? installedAt;
  final DateTime? uninstalledAt;

  bool get subscribed => plan != AdminPlan.none;
  bool get reachedPaywall => paywallViews > 0 || steps.containsKey('paywall_view');
  bool get triedToPay => paymentAttempts > 0 || steps.containsKey('subscribe_tap');
  bool get churned => everSubscribed && plan == AdminPlan.none;

  double get paidTotal =>
      payments.fold(0.0, (sum, payment) => sum + payment.amount);

  /// The real name; else the real email; else "Guest 3f9a2c"; else "No name".
  /// Never an invented one.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.trim().isNotEmpty) return email.trim();
    if (isGuest) return 'Guest ${id.substring(0, id.length < 6 ? id.length : 6)}';
    return 'No name';
  }

  /// "SM" for Sana Mehta; the first letters of the first two words.
  String get initials {
    final source = displayName.contains('@') ? displayName.split('@').first : displayName;
    final words = source.trim().split(RegExp(r'[\s._-]+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  /// Whether they opened the app on a UTC date like `2026-10-14`.
  bool wasActiveOn(String utcDay) => openDays.contains(utcDay);
}

/// Everything the panel loads.
class AdminData {
  const AdminData({required this.users, required this.devices});

  final List<AdminUser> users;
  final List<AdminDevice> devices;
}

/// Why an account is hidden from the numbers.
class HiddenAccount {
  const HiddenAccount(this.user, this.reason);

  final AdminUser user;
  final String reason;
}

/// One row of the funnel.
class FunnelStep {
  const FunnelStep(this.label, this.count);

  final String label;
  final int count;
}

/// A person with the time that put them on a list ("Installed 14:32").
class PersonEntry {
  const PersonEntry(this.user, {this.time, this.note});

  final AdminUser user;
  final DateTime? time;
  final String? note;
}

/// One day of the two charts.
class DayStats {
  const DayStats({
    required this.day,
    required this.active,
    required this.installed,
    required this.uninstalled,
  });

  /// A UTC calendar day.
  final DateTime day;
  final List<PersonEntry> active;
  final List<PersonEntry> installed;
  final List<PersonEntry> uninstalled;

  int get net => installed.length - uninstalled.length;
}

/// A group of people behind one bar or one count, for the lists they open.
class ReasonCount {
  const ReasonCount(this.label, this.people);

  final String label;
  final List<PersonEntry> people;

  int get count => people.length;
}

/// Everything the dashboard shows, computed from the visible users.
class AdminStats {
  const AdminStats({
    required this.users,
    required this.subscribedUsers,
    required this.activeToday,
    required this.paidLast30,
    required this.newThisWeek,
    required this.activeThisWeek,
    required this.revenueTotal,
    required this.revenue30,
    required this.costs30,
    required this.costLines,
    required this.days,
    required this.funnel,
    required this.installedPhones,
    required this.failures,
    required this.sources,
  });

  final List<AdminUser> users;
  final List<AdminUser> subscribedUsers;
  final List<AdminUser> activeToday;
  final List<AdminUser> paidLast30;
  final int newThisWeek;
  final int activeThisWeek;
  final double revenueTotal;
  final double revenue30;
  final double costs30;
  final Map<String, double> costLines;

  /// Oldest first; the last entry is today (UTC).
  final List<DayStats> days;
  final List<FunnelStep> funnel;
  final int installedPhones;

  /// Why paying did not happen: cancelled, failed, store not available.
  final List<ReasonCount> failures;

  /// Where people heard about Mayow, most first.
  final List<ReasonCount> sources;

  int get totalUsers => users.length;
  int get paying => subscribedUsers.length;
  double get profitBeforeCut => revenue30 - costs30;
}

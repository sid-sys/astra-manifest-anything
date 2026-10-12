/// The plan an account is on. `none` is free, or a subscription that ended.
enum AdminPlan { none, monthly, yearly, lifetime }

/// The kinds of thing the app reports. One list, so the analytics service, the
/// mock data and the screens agree on spelling.
class EventType {
  const EventType._();

  static const opened = 'opened';
  static const onboardingDone = 'onboarding_done';
  static const wishTyped = 'wish_typed';
  static const paywallView = 'paywall_view';
  static const paymentAttempt = 'payment_attempt';
  static const subscribed = 'subscribed';
  static const payment = 'payment';
  static const manifestationMade = 'manifestation_made';
  static const affirmationsMade = 'affirmations_made';
}

/// An emoji and a title for an event type, for the activity lists.
({String emoji, String title}) describeEvent(String type) => switch (type) {
  EventType.opened => (emoji: '👋', title: 'Opened the app'),
  EventType.onboardingDone => (emoji: '✅', title: 'Finished onboarding'),
  EventType.wishTyped => (emoji: '✍️', title: 'Typed a wish'),
  EventType.paywallView => (emoji: '💳', title: 'Saw the paywall'),
  EventType.paymentAttempt => (emoji: '🛒', title: 'Tried to pay'),
  EventType.subscribed => (emoji: '🎉', title: 'Subscribed'),
  EventType.payment => (emoji: '💰', title: 'Payment'),
  EventType.manifestationMade => (emoji: '🌙', title: 'Made a manifestation'),
  EventType.affirmationsMade => (emoji: '✨', title: 'Made affirmations'),
  _ => (emoji: '•', title: type),
};

/// One thing a person did.
class AdminEvent {
  const AdminEvent({
    required this.time,
    required this.type,
    this.detail = '',
  });

  final DateTime time;
  final String type;
  final String detail;
}

/// One payment, in dollars.
class AdminPayment {
  const AdminPayment({required this.time, required this.amount});

  final DateTime time;
  final double amount;
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
    required this.onboardingComplete,
    required this.typedWish,
    required this.paywallViews,
    required this.paymentAttempts,
    required this.plan,
    required this.subscribedAt,
    required this.payments,
    required this.events,
    required this.streak,
    this.everSubscribed = false,
  });

  final String id;
  final String name;
  final String email;
  final String country;
  final DateTime joinedAt;
  final DateTime lastSeen;

  /// The funnel steps, in order: onboarding, [typedWish], paywall, payment.
  final bool onboardingComplete;
  final bool typedWish;
  final int paywallViews;
  final int paymentAttempts;

  final AdminPlan plan;
  final DateTime? subscribedAt;
  final List<AdminPayment> payments;

  /// Newest first.
  final List<AdminEvent> events;
  final int streak;

  /// Paid at some point, even if the plan has since ended.
  final bool everSubscribed;

  bool get subscribed => plan != AdminPlan.none;
  bool get reachedPaywall => paywallViews > 0;
  bool get triedToPay => paymentAttempts > 0;
  bool get churned => everSubscribed && plan == AdminPlan.none;

  double get paidTotal =>
      payments.fold(0.0, (sum, payment) => sum + payment.amount);

  /// "SM" for Sana Mehta; the first letters of the first two words.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  bool wasActiveOn(DateTime day) => events.any(
    (event) =>
        event.time.year == day.year &&
        event.time.month == day.month &&
        event.time.day == day.day,
  );
}

/// One row of the "joined to subscribed" funnel.
class FunnelStep {
  const FunnelStep(this.label, this.count);

  final String label;
  final int count;
}

/// Everything the dashboard shows, computed from the user list.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.newThisWeek,
    required this.subscribed,
    required this.paying,
    required this.lifetime,
    required this.activeToday,
    required this.activeThisWeek,
    required this.revenueTotal,
    required this.revenue30,
    required this.costs30,
    required this.costLines,
    required this.dailyActive,
    required this.funnel,
  });

  final int totalUsers;
  final int newThisWeek;

  /// Anyone on a paid plan now (monthly, yearly or lifetime).
  final int subscribed;

  /// Monthly and yearly only: the ones who pay again.
  final int paying;
  final int lifetime;
  final int activeToday;
  final int activeThisWeek;
  final double revenueTotal;
  final double revenue30;
  final double costs30;

  /// The costs behind [costs30], one line each, for the sub-line.
  final Map<String, double> costLines;

  /// Oldest first; the last entry is today.
  final List<({DateTime day, int count})> dailyActive;
  final List<FunnelStep> funnel;

  double get subscribedShare => totalUsers == 0 ? 0 : subscribed / totalUsers;
  double get profitBeforeCut => revenue30 - costs30;
}

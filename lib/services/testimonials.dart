/// A review from a real person who actually used Mayow.
class Testimonial {
  const Testimonial({
    required this.quote,
    required this.name,
    required this.stars,
    this.photoAsset,
  });

  final String quote;

  /// However the reviewer agreed to be credited — a first name, an initial, a
  /// handle. Not invented.
  final String name;
  final int stars;

  /// A bundled asset path. Null shows their initial instead, which is a
  /// perfectly good card and always better than someone else's face.
  final String? photoAsset;
}

/// The reviews shown before the paywall.
///
/// **Empty on purpose, and it must stay empty until real ones exist.**
///
/// The screenshots this was modelled on show three five-star reviews with
/// three photographs of women. Writing that copy is ten minutes of work and
/// the resulting screen would be indistinguishable from the real thing — which
/// is exactly the problem. Testimonials that nobody said, attached to faces
/// that belong to strangers or to a generator, are fabricated endorsements.
/// In the US the FTC's endorsement rules treat them as deceptive advertising
/// and, since 2024, fine per violation; the fact that they appear in front of
/// a paywall is what makes them material. India's Consumer Protection Act
/// takes the same position on misleading advertisements. For an app that makes
/// claims about people's lives — money arriving, an ex coming back — invented
/// proof is the specific thing regulators look for.
///
/// So the screen is built and the list is empty. Add entries here when you
/// have reviews you can point at: a real user who agreed to be quoted, the
/// words they actually wrote, and a photo you have their permission to use.
/// Anything you cannot source, leave out — [ProofScreen] skips itself entirely
/// while this is empty, so an honest app with no reviews yet simply does not
/// show a review screen. That costs a little conversion and nothing else.
///
/// The App Store and Play Store both surface real reviews for free once you
/// have them. Screenshots of those, with the reviewer's own words, are the
/// usual honest version of this screen.
const testimonials = <Testimonial>[];

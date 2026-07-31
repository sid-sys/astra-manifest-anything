import 'dart:math';

import '../models/intention.dart';

/// Starter wishes, offered when the box is empty.
///
/// A blank field asking someone to name what they want is a hard prompt to
/// answer cold. These are deliberately concrete and slightly awkward — "I want
/// to marry her", not "I want love" — because the specific ones are what the
/// story generator can actually build a scene out of, and seeing one makes it
/// obvious what kind of answer belongs here.
class WishPrompts {
  const WishPrompts._();

  static const _byIntention = {
    Intention.career: [
      'I want to run my own studio',
      'I want to be the one they call when it matters',
      'I want to leave the job that is making me small',
      'I want my work to be something I am proud to name',
    ],
    Intention.abundance: [
      'I want to be a millionaire one day',
      'I want to stop checking my balance before I buy food',
      'I want to pay off everything I owe',
      'I want to buy my parents a house',
    ],
    Intention.love: [
      'I want to marry her',
      'I want someone who is glad I came home',
      'I want to stop settling for people who are almost right',
      'I want us to be good again',
    ],
    Intention.health: [
      'I want to wake up without hurting',
      'I want to run five kilometres without stopping',
      'I want to stop being afraid of my own body',
      'I want to sleep through a whole night',
    ],
    Intention.confidence: [
      'I want to speak up in the room and not shake',
      'I want to stop apologising for taking up space',
      'I want to send the email without rewriting it four times',
      'I want to walk in like I belong there',
    ],
    Intention.peace: [
      'I want to travel around the UK with nowhere to be',
      'I want a morning that nobody needs anything from',
      'I want to put my phone down and not reach for it',
      'I want to stop bracing for the next thing',
    ],
  };

  /// A wish for [intention], different from [previous] where possible.
  ///
  /// Rotating rather than randomising: an unlucky shuffle that returns the
  /// line already on screen reads as a broken button.
  static String next(
    Intention intention, {
    String? previous,
    Random? random,
  }) {
    final pool = _byIntention[intention] ?? _byIntention[Intention.career]!;
    if (pool.length == 1) return pool.first;

    final index = previous == null ? -1 : pool.indexOf(previous);
    if (index != -1) return pool[(index + 1) % pool.length];

    return pool[(random ?? Random()).nextInt(pool.length)];
  }
}

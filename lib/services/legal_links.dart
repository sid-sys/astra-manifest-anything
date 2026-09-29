import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The pages Play requires and users deserve.
///
/// Served by GitHub Pages from github.com/sid-sys/policies, which is public
/// and separate from this repository on purpose: Google has to be able to read
/// these without an app build, and a policy URL that goes dark between reviews
/// is a rejected listing.
///
/// The same three URLs are typed into the Play Console. Changing one here means
/// changing it there, and in the policies repo — [deleteAccount] in particular
/// is entered under Data safety as the account-deletion URL.
///
/// A copy of each page also lives in `web/`, so the Firebase-hosted web build
/// carries them too. The repo is the canonical one.
class LegalLinks {
  const LegalLinks._();

  static const _base = 'https://sid-sys.github.io/policies';

  static const privacy = '$_base/privacy.html';
  static const terms = '$_base/terms.html';
  static const deleteAccount = '$_base/delete-account.html';

  static const supportEmail = 'support@coreinteractive.live';

  /// Google Play's own subscription page for this app.
  ///
  /// Deep-linked to Maya rather than to the list of every subscription the
  /// user has, because "go to Play, find us among fourteen others, then cancel"
  /// is the shape of a dark pattern even when it is only laziness.
  ///
  /// Cancelling has to happen at Play. The app cannot do it — Google owns the
  /// billing relationship — so the honest thing is to put them one tap from the
  /// button rather than pretend the app has one.
  static String playSubscription(String productId, String packageName) =>
      'https://play.google.com/store/account/subscriptions'
      '?sku=$productId&package=$packageName';

  /// Opens [url] in the browser, outside the app.
  ///
  /// Failure is swallowed to a snackbar rather than thrown: a device with no
  /// browser is rare but real, and it is not worth a crash over a link to a
  /// policy page.
  static Future<void> open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

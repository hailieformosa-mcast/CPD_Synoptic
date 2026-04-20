import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase setup helper. This is a lightweight skeleton to initialize
/// Firebase and log events. Add your `google-services.json` (Android) and
/// `GoogleService-Info.plist` (iOS) to the platform folders as usual.

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // If platform-specific Firebase options are not provided (e.g. web not configured),
      // don't crash the app—analytics will be disabled until proper config is added.
      // Logged for debugging.
      // ignore: avoid_print
      print('Firebase.initializeApp() skipped or failed: $e');
    }
  }

  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  Future<void> logMoveToCart(String itemName, String quantity) async {
    await analytics.logEvent(
      name: 'move_to_cart',
      parameters: {'item': itemName, 'quantity': quantity},
    );
  }

  Future<void> logAddItem(String itemName) async {
    await analytics.logEvent(name: 'add_item', parameters: {'item': itemName});
  }

  Future<void> logRemoveItem(String itemName) async {
    await analytics.logEvent(name: 'remove_item', parameters: {'item': itemName});
  }

  Future<void> logViewMap() async {
    await analytics.logEvent(name: 'view_map');
  }
}

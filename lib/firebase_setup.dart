import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase setup helper. This is a lightweight skeleton to initialize
/// Firebase and log events. Add your `google-services.json` (Android) and
/// `GoogleService-Info.plist` (iOS) to the platform folders as usual.

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  Future<void> initialize() async {
    await Firebase.initializeApp();
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
}

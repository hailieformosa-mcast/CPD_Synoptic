Appendix — Task 6 (Version Control, Analytics, CI/CD)

1) Git & Commit Guidance
- Ensure you push your repository to GitHub and include a link in your submission.
- Example commit messages (8 meaningful commits):
  - Init project: basic Flutter scaffold
  - Add Provider state management
  - Implement Add/Edit Item screen and validation
  - Integrate flutter_map and Overpass POI fetch
  - Add Hive persistence for lists
  - Implement item edit and in-cart toggle
  - Integrate local notifications
  - Polish UI and About page

2) GitHub Actions (CI) — workflow file (already added as `.github/workflows/flutter_ci.yml`)
- Purpose: run `flutter analyze` and `flutter test` on push and pull requests to catch errors early.

Workflow contents (repeat):
```yaml
name: Flutter CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Analyze
        run: flutter analyze
      - name: Run tests
        run: flutter test --coverage
```

3) Firebase Analytics integration (skeleton)
- Files to add: `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) — download from Firebase console.
- Dependencies (pubspec.yaml): `firebase_core`, `firebase_analytics` (already added).
- Initialization example (call in `main()` before runApp):
```dart
await Firebase.initializeApp();
```
- Example event logging (from `lib/firebase_setup.dart`):
```dart
FirebaseAnalytics.instance.logEvent(name: 'move_to_cart', parameters: {'item': itemName});
```
- Evidence: trigger events in the running app, then take a screenshot of Firebase Console → Analytics → Events.

4) What to include in your report
- Repository link and a screenshot of the commit history showing >=8 commits.
- A copy of `.github/workflows/flutter_ci.yml` (or the file path) and one-sentence explanation.
- Firebase Console screenshot showing example events and a short list of tracked events.
- `MAINTENANCE.md` contents (three realistic updates with effort estimation and compatibility notes).

5) Quick commands
- Create a branch for each major feature and commit frequently:
```bash
git checkout -b feat/hive-persistence
git add .
git commit -m "Add Hive persistence for shopping lists"
```
- Push to remote (after adding remote):
```bash
git push -u origin main
```

End of Appendix.

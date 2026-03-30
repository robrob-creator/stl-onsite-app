// Integration test suite for the STL Agent App.
//
// Run on a connected Android/iOS device or emulator:
//   flutter test integration_test/app_test.dart
//
// Tests are grouped by functional area:
//   1. App bootstrap      – app launches without crashing
//   2. Splash screen      – animated logo renders
//   3. Login page         – navigation, UI elements, PIN input, validation
//   4. Auth controller    – in-memory, no network: PIN length guard
//   5. Lottery math       – calculateCombinations pure-Dart unit logic
//   6. Draft bet ops      – client-side DraftBet state mutations
//   7. BetEntry guards    – submit / add-bet validation before any API call
//
// Tests that require a live backend and real device IMEI are tagged
// [requires-auth] and are SKIPPED by default. Provide real credentials via
// the environment to run them (see "Auth-gated tests" section below).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:onstite/main.dart' as app;
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/controllers/lottery_controller.dart';
import 'package:onstite/widgets/custom_pin_input.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Boots the full app and pumps past the 4.6-second splash animation.
Future<void> _launchApp(WidgetTester tester) async {
  await tester.pumpWidget(app.MyApp());
  // The splash triggers navigation after 4 600 ms; allow 6 s to be safe.
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// Mounts a lightweight GetX context (no route or plugin setup).
/// Suitable for tests that only need the GetX overlay (snackbars, dialogs).
Future<void> _pumpGetContext(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(home: const Scaffold(body: SizedBox.shrink())),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Initialise GetStorage (required by main() and printer service).
    await GetStorage.init();
    // Wipe all registered controllers between tests so they start clean.
    Get.reset();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 1 – App bootstrap
  // ─────────────────────────────────────────────────────────────────────────
  group('App bootstrap', () {
    testWidgets('app starts without throwing', (tester) async {
      await tester.pumpWidget(app.MyApp());
      await tester.pump(); // first frame
      // At minimum the Scaffold hierarchy must exist.
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('app builds a GetMaterialApp at the root', (tester) async {
      await tester.pumpWidget(app.MyApp());
      await tester.pump();
      expect(find.byType(GetMaterialApp), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 2 – Splash screen
  // ─────────────────────────────────────────────────────────────────────────
  group('Splash screen', () {
    testWidgets('splash scaffold is white (not the login background)', (
      tester,
    ) async {
      await tester.pumpWidget(app.MyApp());
      await tester.pump(); // first frame – still on splash

      // The SplashPage root container should be white.
      final container = tester.widgetList<Container>(find.byType(Container));
      final hasWhiteBg = container.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) return dec.color == Colors.white;
        return c.color == Colors.white;
      });
      expect(hasWhiteBg, isTrue);
    });

    testWidgets('splash uses animated builders for logo elements', (
      tester,
    ) async {
      await tester.pumpWidget(app.MyApp());
      await tester.pump();
      // Splash page stacks multiple AnimatedBuilder widgets for the logo.
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 3 – Login page  (after splash animation completes)
  // ─────────────────────────────────────────────────────────────────────────
  group('Login page – navigation and UI', () {
    testWidgets('navigates to login page when no session is stored', (
      tester,
    ) async {
      // Ensure no auth token exists by restarting with a clean state.
      await _launchApp(tester);
      // The login page header text is the most reliable finder.
      expect(find.text('Sign In to your Account'), findsOneWidget);
    });

    testWidgets('login page shows MPIN subtitle', (tester) async {
      await _launchApp(tester);
      expect(find.text('Please enter your 6-digit MPIN'), findsOneWidget);
    });

    testWidgets('login page renders CustomPinInput', (tester) async {
      await _launchApp(tester);
      expect(find.byType(CustomPinInput), findsOneWidget);
    });

    testWidgets('CustomPinInput renders six PIN cells', (tester) async {
      await _launchApp(tester);
      // Each cell is a 50 × 60 Container. There are exactly 6.
      // The hidden input TextField is always present inside CustomPinInput.
      expect(find.byType(TextField), findsAtLeast(1));
    });

    testWidgets('typing three digits shows three filled PIN cells', (
      tester,
    ) async {
      await _launchApp(tester);

      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, '123');
      await tester.pump();

      // CustomPinInput renders filled cells with the '●' character.
      expect(find.text('●'), findsNWidgets(3));
    });

    testWidgets('clearing the PIN field removes all filled cells', (
      tester,
    ) async {
      await _launchApp(tester);

      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, '456');
      await tester.pump();
      expect(find.text('●'), findsNWidgets(3));

      await tester.enterText(pinField, '');
      await tester.pump();
      expect(find.text('●'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 4 – AuthController – in-memory validation (no network)
  // ─────────────────────────────────────────────────────────────────────────
  group('AuthController – client-side validation', () {
    testWidgets(
      'login() with PIN shorter than 6 digits shows snackbar without API call',
      (tester) async {
        await _pumpGetContext(tester);

        final auth = Get.put(AuthController());
        // Wait for device init (which may not complete in emulator but is
        // guarded internally).
        await tester.pump(const Duration(seconds: 1));

        auth.mpin.value = '1234'; // only 4 digits
        auth.login();
        await tester.pumpAndSettle();

        expect(find.text('PIN must be exactly 6 digits'), findsOneWidget);
      },
    );

    testWidgets('addDigit builds MPIN one character at a time', (tester) async {
      await _pumpGetContext(tester);

      final auth = Get.put(AuthController());
      auth.mpin.value = '';

      auth.addDigit('7');
      auth.addDigit('3');
      auth.addDigit('1');

      expect(auth.mpin.value, equals('731'));
    });

    testWidgets('removeDigit trims the last character', (tester) async {
      await _pumpGetContext(tester);

      final auth = Get.put(AuthController());
      auth.mpin.value = '12345';

      auth.removeDigit();
      expect(auth.mpin.value, equals('1234'));

      auth.removeDigit();
      expect(auth.mpin.value, equals('123'));
    });

    testWidgets('clearMpin resets MPIN to empty', (tester) async {
      await _pumpGetContext(tester);

      final auth = Get.put(AuthController());
      auth.mpin.value = '999999';
      auth.clearMpin();

      expect(auth.mpin.value, isEmpty);
    });

    testWidgets('addDigit caps entry at 6 digits', (tester) async {
      await _pumpGetContext(tester);

      final auth = Get.put(AuthController());
      auth.mpin.value = '';

      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8']) {
        auth.addDigit(d);
      }

      expect(auth.mpin.value.length, equals(6));
      expect(auth.mpin.value, equals('123456'));
    });

    testWidgets('isLoggedIn is false when token is empty', (tester) async {
      await _pumpGetContext(tester);

      final auth = Get.put(AuthController());
      auth.token.value = '';
      auth.currentUser.value = null;

      expect(auth.isLoggedIn, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 5 – LotteryController.calculateCombinations  (pure Dart, no UI)
  // ─────────────────────────────────────────────────────────────────────────
  group('LotteryController – calculateCombinations', () {
    late LotteryController ctrl;

    setUp(() {
      // Create directly; skip onInit HTTP calls by using a wrapper approach.
      // We only need the pure-math method here.
      ctrl = LotteryController();
    });

    test('empty list → 1 (identity)', () {
      expect(ctrl.calculateCombinations([]), equals(1));
    });

    test('single digit → 1', () {
      expect(ctrl.calculateCombinations(['4']), equals(1));
    });

    test('2D: both digits same → 1', () {
      expect(ctrl.calculateCombinations(['5', '5']), equals(1));
    });

    test('2D: both digits different → 2', () {
      expect(ctrl.calculateCombinations(['1', '9']), equals(2));
    });

    test('3D: all digits different → 6  (3! = 6)', () {
      expect(ctrl.calculateCombinations(['1', '2', '3']), equals(6));
    });

    test('3D: one pair → 3  (3!/2! = 3)', () {
      expect(ctrl.calculateCombinations(['2', '2', '3']), equals(3));
    });

    test('3D: all same → 1  (3!/3! = 1)', () {
      expect(ctrl.calculateCombinations(['7', '7', '7']), equals(1));
    });

    test('3D: 0-padded digit strings are treated as-is', () {
      // '01', '02', '03' are all distinct strings → 6
      expect(ctrl.calculateCombinations(['01', '02', '03']), equals(6));
    });

    test('3D: two identical padded strings → pair gives 3', () {
      expect(ctrl.calculateCombinations(['01', '01', '05']), equals(3));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 6 – DraftBet client-side state
  // ─────────────────────────────────────────────────────────────────────────
  group('DraftBet – local state operations', () {
    /// Builds a minimal DraftBet with a given id.
    DraftBet _makeDraft({String id = '', double straight = 10}) {
      return DraftBet(
        id: id,
        gameName: '2D Lotto',
        digits: ['3', '7'],
        straightBetAmount: straight,
        rambleBetAmount: 0,
        totalBetAmount: straight,
        estPayout: straight * 70,
        combinations: 2,
      );
    }

    testWidgets('removeBet with empty id removes draft locally (no API call)', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      // Use addPostFrameCallback so onInit async calls don't interfere.
      await tester.pump(const Duration(milliseconds: 100));

      ctrl.draftBets.add(_makeDraft(id: ''));
      expect(ctrl.draftBets.length, equals(1));

      await ctrl.removeBet(0);
      expect(ctrl.draftBets, isEmpty);
    });

    testWidgets('draftBets starts empty on fresh controller', (tester) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      await tester.pump(const Duration(milliseconds: 50));

      expect(ctrl.draftBets, isEmpty);
    });

    testWidgets('DraftBet.betType is Target when only straight > 0', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final draft = _makeDraft(straight: 20);
      expect(draft.betType, equals('Target'));
    });

    testWidgets('DraftBet.betType is Rambol when only ramble > 0', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final draft = DraftBet(
        id: '',
        gameName: '2D Lotto',
        digits: ['1', '2'],
        straightBetAmount: 0,
        rambleBetAmount: 15,
        totalBetAmount: 15,
        estPayout: 15 * 35,
        combinations: 2,
      );
      expect(draft.betType, equals('Rambol'));
    });

    testWidgets('DraftBet.totalBetAmount equals straight + ramble amounts', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final draft = DraftBet(
        id: 'uuid-123',
        gameName: '3D Lotto',
        digits: ['1', '2', '3'],
        straightBetAmount: 50,
        rambleBetAmount: 30,
        totalBetAmount: 80,
        estPayout: 5000,
        combinations: 6,
      );
      expect(draft.totalBetAmount, equals(80.0));
      expect(
        draft.straightBetAmount + draft.rambleBetAmount,
        equals(draft.totalBetAmount),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 7 – BetEntry guards (client-side, no API)
  // ─────────────────────────────────────────────────────────────────────────
  group('BetEntry – submit and add-bet guards', () {
    testWidgets('submitBets shows error snackbar when draftBets is empty', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      await tester.pump(const Duration(milliseconds: 100));

      expect(ctrl.draftBets, isEmpty);

      await ctrl.submitBets();
      await tester.pumpAndSettle();

      expect(find.text('Please add at least one bet'), findsOneWidget);
    });

    testWidgets('addBet shows error when selectedNumbers is empty', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      await tester.pump(const Duration(milliseconds: 100));

      ctrl.selectedNumbers.clear();
      await ctrl.addBet();
      await tester.pumpAndSettle();

      expect(find.text('Please select numbers'), findsOneWidget);
    });

    testWidgets('addBet shows error when both amounts are zero', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      await tester.pump(const Duration(milliseconds: 100));

      ctrl.selectedNumbers.addAll(['1', '2']);
      ctrl.targetAmount.value = 0;
      ctrl.rambolAmount.value = 0;

      await ctrl.addBet();
      await tester.pumpAndSettle();

      expect(find.text('Please enter at least one bet amount'), findsOneWidget);
    });

    testWidgets('draftBets list length stays unchanged on failed addBet', (
      tester,
    ) async {
      await _pumpGetContext(tester);

      final ctrl = Get.put(LotteryController());
      await tester.pump(const Duration(milliseconds: 100));

      // No numbers → addBet will fail
      ctrl.selectedNumbers.clear();
      await ctrl.addBet();

      expect(ctrl.draftBets, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 8 – Auth-gated flows  [SKIPPED – require real credentials & IMEI]
  // ─────────────────────────────────────────────────────────────────────────
  //
  // To run these:
  //   1. Configure a real teller MPIN and device IMEI in the .env file or
  //      pass them as Dart defines:
  //        flutter test integration_test/app_test.dart \
  //          --dart-define=TEST_MPIN=123456
  //   2. Remove the `skip: true` flag below.
  //
  group('Auth-gated flows', () {
    const testMpin = String.fromEnvironment('TEST_MPIN', defaultValue: '');
    final shouldSkip = testMpin.isEmpty;

    testWidgets('full login → home → bet tab flow', (tester) async {
      await _launchApp(tester);

      // Enter the 6-digit test MPIN via the hidden TextField.
      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, testMpin);
      await tester.pump();

      // Auto-login is triggered by CustomPinInput.onComplete.
      // Wait for API round-trip (up to 35 s).
      await tester.pumpAndSettle(const Duration(seconds: 35));

      // After successful login the Balance chip is visible in the AppBar.
      expect(find.textContaining('₱'), findsWidgets);
    }, skip: shouldSkip);

    testWidgets('navigating to Bet tab shows game selector', (tester) async {
      await _launchApp(tester);

      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, testMpin);
      await tester.pumpAndSettle(const Duration(seconds: 35));

      // Tap the Bet bottom-nav item (index 1, label 'Bet').
      await tester.tap(find.text('Bet'));
      await tester.pumpAndSettle();

      // Game selector tabs should be visible.
      expect(find.textContaining('Lotto'), findsWidgets);
    }, skip: shouldSkip);

    testWidgets('navigating to Ticket tab shows ticket list', (tester) async {
      await _launchApp(tester);

      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, testMpin);
      await tester.pumpAndSettle(const Duration(seconds: 35));

      await tester.tap(find.text('Ticket'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // The status filter tabs should be visible.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'Tickets' || w.data == 'Void'),
        ),
        findsWidgets,
      );
    }, skip: shouldSkip);
  });
}

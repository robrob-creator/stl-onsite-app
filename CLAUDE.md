# CLAUDE.md — Onstite (STL Agent App)

> This file is the single source of truth for AI-assisted development on this project.
> Read this before touching any code.

---

## Project Overview

**App name:** STL App (Small Town Lottery)  
**Package:** `onstite`  
**Platform:** Flutter (Android primary, iOS secondary)  
**Purpose:** Mobile point-of-sale lottery agent app. Authorized tellers place bets (Straight/Rambol), print Bluetooth thermal receipts, view tickets, claim winnings, watch live draws, and generate End-of-Day and Summary financial reports.  
**Auth:** Device-bound — IMEI + 6-digit MPIN → JWT Bearer token.

---

## Tech Stack

| Concern              | Package / Approach                               |
| -------------------- | ------------------------------------------------ |
| State management     | GetX (`get: ^4.6.5`)                             |
| HTTP                 | `http: ^1.1.0`                                   |
| WebSocket            | `dart:io` `WebSocket` (built-in)                 |
| Secure storage       | `flutter_secure_storage` (token, user JSON)      |
| Non-secure storage   | `get_storage` (printer MAC address only)         |
| Device info          | `device_info_plus` (IMEI retrieval)              |
| Printing             | `print_bluetooth_thermal` + `esc_pos_utils_plus` |
| QR scanning          | `qr_code_scanner_plus`                           |
| Images               | `image_gallery_saver_plus`, `widgets_to_image`   |
| WebView              | `webview_flutter` (live draw stream)             |
| Internationalization | `intl` (date/currency formatting)                |

---

## WebSocket

**URL:** `wss://stl-backend-mws9.onrender.com/api/ws?token=<jwt>`

Auth is passed via query param (not headers — WebSocket handshake limitation).

**Service:** `lib/core/services/websocket_service.dart` — `WebSocketService` extends `GetxController`.  
Registered by `AuthController.onInit()` via `Get.put(WebSocketService())`.  
Connected automatically after login and session restore. Disconnected on logout.  
Reconnects with exponential backoff (3s → 4m cap) on unexpected disconnect.  
Sends a WebSocket **ping frame every 20 seconds** (`socket.pingInterval`) to keep the Go server connection alive; the server responds with pong frames automatically.

**Event envelope:**

```json
{ "type": "ticket.voided", "payload": { ... }, "timestamp": "..." }
```

**Event handlers:**

| Event                | Handler location                                  | Behaviour                          |
| -------------------- | ------------------------------------------------- | ---------------------------------- |
| `ticket.voided`      | `AuthController._connectWebSocket()`              | Snackbar (pink)                    |
| `bet.placed`         | `LotteryController._subscribeToWebSocketEvents()` | `loadProfile()` → balance refresh  |
| `bet.bulk_placed`    | Both                                              | Snackbar (green) + balance refresh |
| `draw_result.posted` | `AuthController._connectWebSocket()`              | Snackbar (blue)                    |
| `claim.created`      | `AuthController._connectWebSocket()`              | Snackbar (green)                   |
| `claim.paid`         | Both                                              | Snackbar (green) + balance refresh |

**Adding a new event listener:**

```dart
final ws = Get.find<WebSocketService>();
final unsub = ws.on('some.event', (payload) {
  // handle it
});
// Call unsub() to remove the listener when done
```

**Connection status (observable):**

```dart
Obx(() => Get.find<WebSocketService>().isConnected.value
  ? const Icon(Icons.wifi)
  : const Icon(Icons.wifi_off),
)
```

---

**Base URL:** `https://stl-backend-mws9.onrender.com/api`  
Defined in `lib/core/app_constants.dart` as `AppConstants.apiBaseUrl`.

**Authentication:** All authenticated requests use:

```
Authorization: Bearer <token>
Content-Type: application/json
```

The token is read from `Get.find<AuthController>().token.value`.

**Error handling pattern:**

- All HTTP calls wrap with `.timeout(const Duration(seconds: 30))`
- Errors are surfaced via `Get.snackbar()` at `SnackPosition.BOTTOM`
- 401 responses trigger automatic logout
- API error responses follow: `{ status, code, message, path }`
- Always display the `message` field from the API directly — never hardcode override strings for specific error codes unless explicitly required

---

## Architecture

```
lib/
├── main.dart                      # App entry point, GetMaterialApp
├── controllers/                   # GetxControllers (state + business logic)
│   ├── auth_controller.dart       # Auth, session, IMEI, MPIN
│   └── lottery_controller.dart    # Bets, games, draw times, balance
├── core/
│   ├── app_constants.dart         # API base URL
│   ├── design_system.dart         # Barrel export — single import for all UI tokens
│   ├── main_layout.dart           # Shared scaffold: AppBar, Drawer, BottomNav
│   ├── components/                # Reusable UI components
│   ├── layout/                    # VSpacer, HSpacer, AppCard, responsive helpers
│   ├── services/                  # Static API service classes
│   ├── theme/                     # Colors, typography, spacing, theme
│   └── utils/                     # AppUtils — formatting, validation helpers
├── models/                        # Plain Dart models with fromJson/toJson
├── pages/                         # UI pages
│   ├── splash_page.dart
│   ├── auth/login_page.dart
│   ├── app/                       # All post-auth pages
│   └── settings/printer_settings_page.dart
├── routes/app_routes.dart         # Named routes + GetX page list
└── widgets/                       # Custom widgets (PIN input, lotto number input, receipt modal)
```

---

## State Management Rules

- Use **GetX** exclusively. No `Provider`, no `Riverpod`, no `BLoC`.
- Controllers extend `GetxController`.
- State fields use `.obs` (e.g., `RxBool isLoading = false.obs`).
- UI rebuilds use `Obx(...)` for fine-grained reactivity or `GetBuilder<T>` when rebuilding a larger subtree.
- Inject controllers via `Get.find<T>()` — controllers are registered in `main.dart` or lazily via `GetPage`.
- Do **not** use `setState` for data that belongs to a controller.

---

## Service Layer Rules

- All API communication lives in `lib/core/services/` as **static classes**.
- Services are not controllers — they have no state.
- Every authenticated service method reads the token via:
  ```dart
  final token = Get.find<AuthController>().token.value;
  ```
- Services return parsed model objects or throw on failure.
- Do not add `GetxController` inheritance to service classes.

---

## Model Rules

- Models use **manual** `fromJson` / `toJson` — no `json_serializable`, no code gen.
- Defensive parsing for arrays: handle both `String` (PostgreSQL literal `"{31,14}"`) and `List` formats.
- All model fields should match the API response naming.

---

## Navigation Rules

Named routes are defined in `lib/routes/app_routes.dart`.

| Route               | Constant                    | Page                  |
| ------------------- | --------------------------- | --------------------- |
| `/splash`           | `AppRoutes.splash`          | `SplashPage`          |
| `/login`            | `AppRoutes.login`           | `LoginPage`           |
| `/home`             | `AppRoutes.home`            | `HomePage`            |
| `/bet-entry`        | `AppRoutes.betEntry`        | `BetEntryPage`        |
| `/receipt`          | `AppRoutes.receipt`         | `ReceiptPage`         |
| `/printer-settings` | `AppRoutes.printerSettings` | `PrinterSettingsPage` |

Pages inside `HomePage` (Dashboard, Bet, Ticket, Claims, Live, Transactions) use `BottomNavigationBar` tab switching — **not** named routes.

Pages like `SummaryReportPage` and `EodReportPage` are pushed via `Navigator.of(context).push(MaterialPageRoute(...))` from the drawer.

---

## Design System

**Single import for all UI:** `import 'package:onstite/core/design_system.dart';`

Never hardcode colors, font sizes, or spacing. Always use design tokens.

### Colors (`AppColors`)

```dart
AppColors.primary          // #2563EB (blue)
AppColors.primaryLight     // #EFF6FF
AppColors.primaryDark      // #1E40AF
AppColors.secondary        // #F97316 (orange)
AppColors.success          // #10B981
AppColors.error            // #EF4444
AppColors.warning          // #FB923C
AppColors.textPrimary      // #1F2937
AppColors.textSecondary    // #6B7280
AppColors.backgroundWhite  // #FFFFFF
AppColors.border           // #E5E7EB
```

### Spacing (`AppSpacing`)

```dart
AppSpacing.xs   // 4
AppSpacing.sm   // 8
AppSpacing.md   // 12
AppSpacing.lg   // 16
AppSpacing.xl   // 20
AppSpacing.xxl  // 24
AppSpacing.xxxl // 32
```

### Typography (`AppTextStyles`)

Scale from `displayLarge` (32px Bold) down to `labelSmall` (11px Medium). Always pick from the scale — never write `TextStyle(fontSize: X)` inline.

---

## MainLayout

`MainLayout` is the shared scaffold wrapping authenticated pages.

```dart
MainLayout(
  title: 'Page Title',
  body: YourWidget(),
  activeDrawerItem: 'summary_report', // optional — highlights drawer item
  currentIndex: 0,                    // BottomNav selected index
  onBottomNavTap: (i) => ...,
  bottomNavItems: [...],
)
```

**Drawer active state:** Pass `activeDrawerItem` string to highlight the correct drawer menu item. Currently supported values: `'summary_report'`. Without this prop, no drawer item appears selected.

---

## Key Business Logic

### Bet Types

- **Straight (Target):** Fixed number → fixed multiplier payout.
- **Rambol:** All permutations of the digits. Payout = `multiplier / combinations`. Combinations = `n! / ∏(freq!)`.

### Ticket Number Format

Generated client-side: `TKT-{CLUSTER_CODE}-YYYY-MM-DD-HHMMSSmmm`

### IMEI

- Android: `androidInfo.id`
- iOS: `iosInfo.identifierForVendor`

### Sold-Out Check

Before submitting bets, `LotteryController.isBetAvailable()` calls `POST /bets/check-available`. If sold out, the bet is rejected with a snackbar.

---

## Coding Conventions

1. **Error messages:** Always display `message` from the API response body. Never override with hardcoded strings unless specifically required.
2. **Async calls:** Always use `try/catch`. Wrap with `.timeout(const Duration(seconds: 30))` (10s for availability checks).
3. **Loading state:** Set `isLoading.value = true` before async work, reset in `finally`.
4. **Snackbars:** `Get.snackbar('Title', message, snackPosition: SnackPosition.BOTTOM)`.
5. **Secure vs. non-secure:** Auth token and user JSON → `FlutterSecureStorage`. Printer MAC → `GetStorage`.
6. **No hardcoded colors/sizes** in page or widget files — use `AppColors`, `AppSpacing`, `AppTextStyles`.
7. **Imports:** Use package imports (`package:onstite/...`) not relative imports across feature boundaries. Relative imports are fine within the same folder.
8. **No `print()` in production code** — existing debug prints (`✓`, `⚠`, `✗` prefixed) are acceptable in controller `onInit` flows.

---

## Common Patterns

### Authenticated HTTP request

```dart
final response = await http.get(
  Uri.parse('${AppConstants.apiBaseUrl}/some-endpoint'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${Get.find<AuthController>().token.value}',
  },
).timeout(const Duration(seconds: 30));
```

### Reactive UI with GetX

```dart
Obx(() => isLoading.value
  ? const CircularProgressIndicator()
  : YourWidget(),
)
```

### Adding a new drawer menu item

In `lib/core/main_layout.dart`, add a `ListTile` inside the `Column` under `// Menu Items`. Apply selected highlight using `activeDrawerItem` comparison, matching the pattern of the Summary Report item.

### Adding a new named route

1. Add constant in `AppRoutes` class in `lib/routes/app_routes.dart`.
2. Add `GetPage(name: ..., page: () => YourPage())` to the `pages` list.
3. Navigate with `Get.toNamed(AppRoutes.yourRoute)` or `Get.offNamed(...)`.

---

## File Naming

| Type        | Convention                   | Example                   |
| ----------- | ---------------------------- | ------------------------- |
| Pages       | `snake_case_page.dart`       | `bet_entry_page.dart`     |
| Controllers | `snake_case_controller.dart` | `lottery_controller.dart` |
| Models      | `snake_case.dart`            | `summary_report.dart`     |
| Services    | `snake_case_service.dart`    | `ticket_service.dart`     |
| Widgets     | `snake_case.dart`            | `custom_pin_input.dart`   |

Classes are `PascalCase` matching the file name.

---

## What NOT to Do

- Do not add new state management libraries.
- Do not use `json_serializable` or `freezed` — keep models manual.
- Do not add `GetxController` inheritance to service classes.
- Do not hardcode the API base URL anywhere except `AppConstants`.
- Do not use `Navigator.pushNamed` — use `Get.toNamed` for named routes.
- Do not use inline colors (`Color(0xFF...)`) in page/widget files — use `AppColors`.
- Do not add error handling for impossible scenarios — only validate at API/input boundaries.
- Do not add extra abstraction layers (repositories, use cases) unless there is a clear scaling need.

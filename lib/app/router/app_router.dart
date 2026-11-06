import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/app_controller.dart';
import '../../features/admin/admin_screens.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/calls/calls_screens.dart';
import '../../features/chats/chat_detail_screen.dart';
import '../../features/chats/chats_list_screen.dart';
import '../../features/contacts/contacts_screens.dart';
import '../../features/settings/settings_screens.dart';
import '../theme/design_tokens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final appState = ref.watch(appControllerProvider);

  return GoRouter(
    initialLocation: '/chats',
    redirect: (context, state) {
      final path = state.uri.path;

      // 1. Bootstrap Splash Gate (UI-01)
      if (appState.isBootstrapping) {
        return path == '/splash' ? null : '/splash';
      }

      // 2. Universal Blocker Gate (UI-25: Suspended, Session Expired, DB Migration Error)
      if (appState.blockerReason != BlockerReason.none) {
        return path == '/blocker' ? null : '/blocker';
      }

      // 3. Authentication Gate (UI-02..UI-04)
      final isAuthRoute =
          path == '/welcome' || path == '/signin' || path == '/signup';
      if (!appState.isAuthenticated) {
        return isAuthRoute ? null : '/welcome';
      }

      // 4. App Lock Gate (Biometric / PIN — Section 3.1 & UI-20)
      if (appState.appLockEnabled && appState.isAppLocked) {
        return path == '/applock' ? null : '/applock';
      }

      if (path == '/splash' || isAuthRoute || path == '/applock') {
        return '/chats';
      }

      // 5. Admin RBAC Guard (Section 2.2)
      if (path.startsWith('/admin') && !appState.isAdmin) {
        return '/chats';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashBootstrapScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/applock',
        builder: (context, state) => const AppLockGateScreen(),
      ),
      GoRoute(
        path: '/blocker',
        builder: (context, state) => const UniversalBlockerScreen(),
      ),

      // Main 4-Tab Shell (Section 3.1: CHATS, CALLS, CONTACTS, SETTINGS)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (context, state) => const ChatsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calls',
                builder: (context, state) => const CallsHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsDirectoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Standalone & Deep-Linked Detail Routes (Section 3.2)
      GoRoute(
        path: '/contacts-search',
        builder: (context, state) =>
            const ContactsDirectoryScreen(autoFocusSearch: true),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          return ChatDetailScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId/info',
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          return ChatInfoScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: '/user/:username',
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ContactProfileScreen(username: username);
        },
      ),
      GoRoute(
        path: '/incoming-call',
        builder: (context, state) => const IncomingCallScreen(),
      ),
      GoRoute(
        path: '/call/:callId',
        builder: (context, state) {
          final callId = state.pathParameters['callId'] ?? 'active';
          return ActiveCallScreen(callId: callId);
        },
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacySecurityScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const MyAccountDeviceScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/user/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return AdminUserDetailScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => const AdminAuditLogScreen(),
      ),
    ],
  );
});

/// Main Shell with 64dp Bottom Navigation Bar & 56x30dp `accent.subtle` Pill Indicator (Section 4.3.2)
class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.bgSurface,
          border: Border(
            top: BorderSide(color: palette.borderHairline, width: 0.5),
          ),
        ),
        child: NavigationBar(
          height: AdoetzDimensions.bottomNavBarHeight, // 64dp
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.call_outlined),
              selectedIcon: Icon(Icons.call_rounded),
              label: 'Calls',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

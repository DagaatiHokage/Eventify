import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/search/search_screen.dart';
import '../features/shell/app_shell.dart';

class Routes {
  const Routes._();

  static const home = '/';
  static const search = '/search';
  static const saved = '/saved';
  static const profile = '/profile';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

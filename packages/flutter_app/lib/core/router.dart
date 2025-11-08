import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features_admin/dashboard.dart';
import '../features_admin/user_detail.dart';
import '../features_admin/users_list.dart';
import '../features_customer/home.dart';
import '../features_customer/landing.dart';
import '../features_customer/login.dart';
import '../features_customer/magic_link_login.dart';
import '../features_customer/magic_link_verify.dart';
import '../features_customer/profile.dart';
import '../features_customer/profile_setup.dart';
import '../features_customer/signup.dart';
import '../core/widgets/auth_guard.dart';
import '../features_customer/main_pages_batch.dart';

final GoRouter _customerRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'landing',
      pageBuilder: (context, state) => const MaterialPage(child: LandingPage()),
    ),
    GoRoute(
      path: '/app',
      name: 'home',
      pageBuilder: (context, state) => const MaterialPage(child: HomePage()),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (context, state) => const MaterialPage(child: ProfilePage()),
    ),
    GoRoute(
      path: '/profile-setup',
      name: 'profile-setup',
      pageBuilder: (context, state) =>
          const MaterialPage(child: ProfileSetupPage()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) =>
          const MaterialPage(child: LoginPage(redirectPath: '/app')),
    ),
    GoRoute(
      path: '/login-magic',
      name: 'login-magic',
      pageBuilder: (context, state) => const MaterialPage(
        child: MagicLinkLoginPage(redirectPath: '/app'),
      ),
    ),
    GoRoute(
      path: '/magic-verify',
      name: 'magic-verify',
      pageBuilder: (context, state) => MaterialPage(
        child: MagicLinkVerifyPage(
          redirectPath: '/app',
          token: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: '/magic-verify/:token',
      name: 'magic-verify-path',
      pageBuilder: (context, state) => MaterialPage(
        child: MagicLinkVerifyPage(
          redirectPath: '/app',
          token: state.pathParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      pageBuilder: (context, state) =>
          const MaterialPage(child: SignupPage(redirectPath: '/app')),
    ),
    GoRoute(
      path: '/features',
      name: 'features',
      pageBuilder: (context, state) =>
          const MaterialPage(child: FeaturesPage()),
    ),
    GoRoute(
      path: '/use-cases',
      name: 'use-cases',
      pageBuilder: (context, state) =>
          const MaterialPage(child: UseCasesPage()),
    ),
    GoRoute(
      path: '/pricing',
      name: 'pricing',
      pageBuilder: (context, state) => const MaterialPage(child: PricingPage()),
    ),
    GoRoute(
      path: '/documentation',
      name: 'documentation',
      pageBuilder: (context, state) =>
          const MaterialPage(child: DocumentationPage()),
    ),
    GoRoute(
      path: '/api-reference',
      name: 'api-reference',
      pageBuilder: (context, state) =>
          const MaterialPage(child: ApiReferencePage()),
    ),
    GoRoute(
      path: '/blog',
      name: 'blog',
      pageBuilder: (context, state) => const MaterialPage(child: BlogPage()),
    ),
    GoRoute(
      path: '/support',
      name: 'support',
      pageBuilder: (context, state) => const MaterialPage(child: SupportPage()),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      pageBuilder: (context, state) => const MaterialPage(child: AboutPage()),
    ),
    GoRoute(
      path: '/careers',
      name: 'careers',
      pageBuilder: (context, state) => const MaterialPage(child: CareersPage()),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      pageBuilder: (context, state) => const MaterialPage(child: PrivacyPage()),
    ),
    GoRoute(
      path: '/terms',
      name: 'terms',
      pageBuilder: (context, state) => const MaterialPage(child: TermsPage()),
    ),
  ],
);

final GoRouter _adminRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'dashboard',
      pageBuilder: (context, state) => const MaterialPage(
        child: AuthGuard(
          requireStaff: true,
          redirectTo: '/login',
          child: AdminDashboardPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/users',
      name: 'users-list',
      pageBuilder: (context, state) => const MaterialPage(
        child: AuthGuard(
          requireStaff: true,
          redirectTo: '/login',
          child: UsersListPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/users/:userId',
      name: 'user-detail',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return MaterialPage(
          child: AuthGuard(
            requireStaff: true,
            redirectTo: '/login',
            child: UserDetailPage(userId: userId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => const MaterialPage(
          child: LoginPage(redirectPath: '/', isAdmin: true)),
    ),
    GoRoute(
      path: '/login-magic',
      name: 'login-magic',
      pageBuilder: (context, state) => const MaterialPage(
        child: MagicLinkLoginPage(redirectPath: '/'),
      ),
    ),
    GoRoute(
      path: '/magic-verify',
      name: 'magic-verify',
      pageBuilder: (context, state) => MaterialPage(
        child: MagicLinkVerifyPage(
          redirectPath: '/',
          token: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: '/magic-verify/:token',
      name: 'magic-verify-path',
      pageBuilder: (context, state) => MaterialPage(
        child: MagicLinkVerifyPage(
          redirectPath: '/',
          token: state.pathParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      pageBuilder: (context, state) => const MaterialPage(
          child: SignupPage(redirectPath: '/', isAdmin: true)),
    ),
  ],
);

GoRouter customerRouter() => _customerRouter;
GoRouter adminRouter() => _adminRouter;

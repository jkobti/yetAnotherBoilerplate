import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features_admin/dashboard.dart';
import '../features_admin/user_detail.dart';
import '../features_admin/users_list.dart';
import '../features_customer/home.dart';
import '../features_customer/landing.dart';
import '../features_customer/login.dart';
import '../features_customer/signup.dart';
import '../core/widgets/auth_guard.dart';
import '../features_customer/main_pages_batch.dart';

final GoRouter _customerRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'landing',
      pageBuilder: (context, state) =>
          const MaterialPage(child: LandingPage()),
    ),
    GoRoute(
      path: '/app',
      name: 'home',
      pageBuilder: (context, state) =>
          const MaterialPage(child: HomePage()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) =>
          const MaterialPage(child: LoginPage(redirectPath: '/app')),
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
      pageBuilder: (context, state) =>
          const MaterialPage(child: PricingPage()),
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
      pageBuilder: (context, state) =>
          const MaterialPage(child: BlogPage()),
    ),
    GoRoute(
      path: '/support',
      name: 'support',
      pageBuilder: (context, state) =>
          const MaterialPage(child: SupportPage()),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      pageBuilder: (context, state) =>
          const MaterialPage(child: AboutPage()),
    ),
    GoRoute(
      path: '/careers',
      name: 'careers',
      pageBuilder: (context, state) =>
          const MaterialPage(child: CareersPage()),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      pageBuilder: (context, state) =>
          const MaterialPage(child: PrivacyPage()),
    ),
    GoRoute(
      path: '/terms',
      name: 'terms',
      pageBuilder: (context, state) =>
          const MaterialPage(child: TermsPage()),
    ),
  ],
);

final GoRouter _adminRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'dashboard',
      pageBuilder: (context, state) => MaterialPage(
        child: AuthGuard(
          requireStaff: true,
          redirectTo: '/login',
          child: const AdminDashboardPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/users',
      name: 'users-list',
      pageBuilder: (context, state) => MaterialPage(
        child: AuthGuard(
          requireStaff: true,
          redirectTo: '/login',
          child: const UsersListPage(),
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
      pageBuilder: (context, state) =>
          const MaterialPage(child: LoginPage(redirectPath: '/', isAdmin: true)),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      pageBuilder: (context, state) =>
          const MaterialPage(child: SignupPage(redirectPath: '/', isAdmin: true)),
    ),
  ],
);

GoRouter customerRouter() => _customerRouter;
GoRouter adminRouter() => _adminRouter;

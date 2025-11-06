import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features_admin/dashboard.dart';
import '../features_admin/user_detail.dart';
import '../features_admin/users_list.dart';
import '../features_customer/home.dart';
import '../features_customer/landing.dart';
import '../features_customer/login.dart';
import '../features_customer/signup.dart';

GoRouter customerRouter() => GoRouter(
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
      ],
    );

GoRouter adminRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'dashboard',
          pageBuilder: (context, state) =>
              const MaterialPage(child: AdminDashboardPage()),
        ),
        GoRoute(
          path: '/users',
          name: 'users-list',
          pageBuilder: (context, state) =>
              const MaterialPage(child: UsersListPage()),
        ),
        GoRoute(
          path: '/users/:userId',
          name: 'user-detail',
          pageBuilder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return MaterialPage(child: UserDetailPage(userId: userId));
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features_admin/dashboard.dart';
import '../features_customer/home.dart';
import '../features_customer/login.dart';
import '../features_customer/signup.dart';

GoRouter customerRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) =>
              const MaterialPage(child: HomePage()),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginPage()),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SignupPage()),
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
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginPage()),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SignupPage()),
        ),
      ],
    );

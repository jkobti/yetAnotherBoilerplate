import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features_admin/dashboard.dart';
import '../features_customer/home.dart';

GoRouter customerRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) =>
              const MaterialPage(child: HomePage()),
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
      ],
    );

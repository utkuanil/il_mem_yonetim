import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'shell.dart';

// core
import '../core/auth/user_session.dart';
import '../core/reports/pdf_preview_page.dart' as pdf_preview;

// splash
import '../features/splash/splash_page.dart';

// auth
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/pending_approval_page.dart';

// main pages
import '../features/dashboard/dashboard_page.dart';
import '../features/schools/schools_page.dart';
import '../features/staff/staff_page.dart';
import '../features/students/students_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/inspection/inspection_page.dart';
import '../features/maps/presentation/okullar_harita_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/requests/requests_page.dart';

// admin
import '../features/admin/admin_page.dart';
import '../features/admin/reports/reports_page.dart';
import '../features/admin/analytics/analytics_page.dart';
import '../features/admin/users/admin_users_page.dart';
import '../features/inspection/pages/planli_denetimler_page.dart';

class AppRouter {
  static GoRouter router(BuildContext context) {
    final session = context.read<UserSession>();

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.uri.path;

        if (path == '/splash') return null;
        if (session.loading) return null;

        final isAuthRoute = path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/pending-approval';

        if (!session.isLoggedIn) {
          return isAuthRoute ? null : '/login';
        }

        if (!session.isActive) {
          return path == '/pending-approval' ? null : '/pending-approval';
        }

        if (path == '/login' ||
            path == '/register' ||
            path == '/forgot-password' ||
            path == '/pending-approval') {
          return '/dashboard';
        }

        final adminOnly = path == '/reports' ||
            path == '/analytics' ||
            path == '/admin' ||
            path == '/planli-denetimler' ||
            path == '/admin-users';

        if (adminOnly && !session.isAdmin) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/pending-approval',
          builder: (_, __) => const PendingApprovalPage(),
        ),
        GoRoute(
          path: '/pdf-preview',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;

            return pdf_preview.PdfPreviewPage(
              bytes: extra['bytes'] as Uint8List,
              fileName: extra['fileName'] as String,
              title: extra['title'] as String,
            );
          },
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              path: '/schools',
              builder: (context, state) => const SchoolsPage(),
            ),
            GoRoute(
              path: '/staff',
              builder: (context, state) => const StaffPage(),
            ),
            GoRoute(
              path: '/students',
              builder: (context, state) => const StudentsPage(),
            ),
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsPage(),
            ),
            GoRoute(
              path: '/inspection',
              builder: (context, state) => const InspectionPage(),
            ),
            GoRoute(
              path: '/maps',
              builder: (context, state) => const OkullarHaritaPage(),
            ),
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const AnnouncementsPage(),
            ),
            GoRoute(
              path: '/requests',
              builder: (context, state) => const RequestsPage(),
            ),
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminPage(),
            ),
            GoRoute(
              path: '/planli-denetimler',
              builder: (context, state) => const PlanliDenetimlerPage(),
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsPage(),
            ),
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsPage(),
            ),
            GoRoute(
              path: '/admin-users',
              builder: (context, state) => const AdminUsersPage(),
            ),
          ],
        ),
      ],
    );
  }
}
// lib/core/app_router.dart
// ignore_for_file: unused_import
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/features/admin/admin_dictionaries_page.dart';
import 'package:provider/provider.dart';
import 'package:ohana_store/features/admin/admin_dashboard_page.dart';
import 'package:ohana_store/features/admin/admin_orders_page.dart';
import 'package:ohana_store/features/admin/admin_products_page.dart';
import 'package:ohana_store/features/admin/admin_reviews_page.dart';
import 'package:ohana_store/features/admin/upsert_product_page.dart';
import 'package:ohana_store/features/admin/admin_promocodes_page.dart';
import 'package:ohana_store/features/admin/upsert_promocode_page.dart';
import 'package:ohana_store/features/admin/promocode_report_page.dart';
import 'package:ohana_store/features/admin/admin_users_page.dart';
import 'package:ohana_store/features/admin/admin_user_detail_page.dart';
import 'package:ohana_store/features/admin/admin_desktop_shell.dart';
import 'package:ohana_store/features/warehouse/warehouse_dashboard.dart';
import 'package:ohana_store/features/delivery/delivery_dashboard.dart';
import 'package:ohana_store/features/auth/screens/login_page.dart';
import 'package:ohana_store/features/auth/screens/register_page.dart';
import 'package:ohana_store/features/auth/screens/splash_screen.dart';
import 'package:ohana_store/features/auth/auth_notifier.dart';
import 'package:ohana_store/features/cart/cart_page.dart';
import 'package:ohana_store/features/catalog/catalog_page.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:ohana_store/features/catalog/product_detail_page.dart';
import 'package:ohana_store/features/checkout/checkout_page.dart';
import 'package:ohana_store/features/checkout/order_success_page.dart';
import 'package:ohana_store/features/favorites/favorites_page.dart';
import 'package:ohana_store/features/orders/add_review_page.dart';
import 'package:ohana_store/features/orders/orders_page.dart';
import 'package:ohana_store/features/orders/order_detail_page.dart';
import 'package:ohana_store/features/profile/edit_profile_page.dart';
import 'package:ohana_store/features/profile/profile_page.dart';
import 'package:ohana_store/features/profile/user_addresses_page.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';
import 'package:ohana_store/models/product.dart';
import 'package:ohana_store/models/promocode.dart';
import 'package:ohana_store/widgets/scaffold_with_nav_bar.dart';
import 'package:ohana_store/features/admin/admin_returns_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _adminShellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthNotifier authNotifier) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirectLimit: 15,
    refreshListenable: authNotifier,

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const LoginPage(key: ValueKey('login_page')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminDesktopShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => AdminUserDetailPage(
                  userId: state.pathParameters['id']!,
                  user: state.extra as AdminUser?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/dictionaries',
            builder: (context, state) => const AdminDictionariesPage(),
          ),
          GoRoute(
            path: '/admin/products',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => CatalogProvider(),
              child: const AdminProductsPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const UpsertProductPage(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) =>
                    UpsertProductPage(product: state.extra as Product),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (context, state) => const AdminOrdersPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => OrderDetailPage(
                  orderId: state.pathParameters['id']!,
                  isAdmin: true,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/reviews',
            builder: (context, state) => const AdminReviewsPage(),
          ),
          GoRoute(
            path: '/admin/returns',
            builder: (context, state) => const AdminReturnsPage(),
          ),
          GoRoute(
            path: '/admin/promocodes',
            builder: (context, state) => const AdminPromocodesPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const UpsertPromocodePage(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) =>
                    UpsertPromocodePage(promocode: state.extra as Promocode?),
              ),
              GoRoute(
                path: 'report/:id',
                builder: (context, state) => PromocodeReportPage(
                  promocodeId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/warehouse',
        builder: (context, state) => const WarehouseDashboard(),
        routes: [
          GoRoute(
            path: 'order/:id',
            builder: (context, state) => OrderDetailPage(
              orderId: state.pathParameters['id']!,
              isCollector: true,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryDashboard(),
        routes: [
          GoRoute(
            path: 'order/:id',
            builder: (context, state) => OrderDetailPage(
              orderId: state.pathParameters['id']!,
              isCourier: true,
            ),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogPage(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartPage(),
            routes: [
              GoRoute(
                path: 'checkout',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is List &&
                      extra.isNotEmpty &&
                      extra.every((e) => e is String)) {
                    return CheckoutPage(
                      selectedCartItemIds: extra
                          .map((e) => e.toString())
                          .toSet(),
                    );
                  }
                  return Scaffold(
                    appBar: AppBar(),
                    body: const Center(
                      child: Text('Ошибка: Не выбраны товары.'),
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'addresses',
                builder: (context, state) => const UserAddressesPage(),
              ),
              GoRoute(
                path: 'edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => EditProfilePage(
                  initialData: state.extra as Map<String, dynamic>,
                ),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const OrdersPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        OrderDetailPage(orderId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'favorites',
                builder: (context, state) => const FavoritesPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order-success/:id',
        builder: (context, state) =>
            OrderSuccessPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/add-review',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return AddReviewPage(
            orderItemId: extra['order_item_id']!,
            productId: extra['product_id']!,
          );
        },
      ),
    ],

    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentUser != null;
      final location = state.matchedLocation;
      final isPublicRoute =
          location == '/splash' ||
          location == '/login' ||
          location == '/register';

      if (!isLoggedIn) return isPublicRoute ? null : '/login';
      if (isLoggedIn && (location == '/login' || location == '/register')) {
        return '/splash';
      }
      if (isLoggedIn && (location == '/' || location == '/home')) {
        return '/catalog';
      }
      return null;
    },
  );
}

// lib/features/admin/admin_desktop_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/features/profile/profile_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:provider/provider.dart';

class AdminDesktopShell extends StatelessWidget {
  final Widget child;
  const AdminDesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profileData;
    final String adminName = profile != null
        ? "${profile['first_name']} ${profile['last_name']}"
        : "Администратор";

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          Container(
            width: 260,
            color: AdminColors.sidebar,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 50,
                    color: AdminColors.background,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  adminName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  "ГЛАВНЫЙ МЕНЕДЖЕР",
                  style: TextStyle(
                    color: AdminColors.accentBlue,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 40),
                _menuItem(
                  context,
                  'Дашборд',
                  Icons.dashboard_outlined,
                  '/admin',
                ),
                _menuItem(
                  context,
                  'Товары',
                  Icons.inventory_2_outlined,
                  '/admin/products',
                ),
                _menuItem(
                  context,
                  'Заказы',
                  Icons.local_shipping_outlined,
                  '/admin/orders',
                ),
                _menuItem(
                  context,
                  'Возвраты',
                  Icons.assignment_return_outlined,
                  '/admin/returns',
                ),
                _menuItem(
                  context,
                  'Клиенты',
                  Icons.group_outlined,
                  '/admin/users',
                ),
                _menuItem(
                  context,
                  'Промокоды',
                  Icons.confirmation_number_outlined,
                  '/admin/promocodes',
                ),
                _menuItem(
                  context,
                  'Отзывы',
                  Icons.rate_review_outlined,
                  '/admin/reviews',
                ),

                const Spacer(),

                _menuItem(context, 'Выход', Icons.logout, '', isLogout: true),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, adminName),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          const Text(
            'Панель управления',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 25),
          const SizedBox(width: 20),
          const VerticalDivider(
            color: Colors.white10,
            indent: 10,
            endIndent: 10,
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    String title,
    IconData icon,
    String route, {
    bool isLogout = false,
  }) {
    final bool isSelected =
        !isLogout && GoRouterState.of(context).matchedLocation == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isLogout
              ? Colors.redAccent
              : (isSelected ? Colors.white : Colors.white38),
        ),
        title: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: isLogout
                ? Colors.redAccent
                : (isSelected ? Colors.white : Colors.white38),
            fontSize: 12,
            fontWeight: isSelected || isLogout
                ? FontWeight.bold
                : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
        onTap: () async {
          if (isLogout) {
            await supabase.auth.signOut();
          } else {
            context.go(route);
          }
        },
        selected: isSelected,
        selectedTileColor: AdminColors.accentBlue,
      ),
    );
  }
}

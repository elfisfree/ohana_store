// lib/features/profile/profile_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohana_store/features/profile/profile_provider.dart';
import 'package:ohana_store/main.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profileData;
        final avatarUrl = profile?['avatar_url'] as String?;
        final isLoading = provider.isLoading;

        String formattedDob = '';
        if (profile?['date_of_birth'] != null) {
          final dob = DateTime.tryParse(profile!['date_of_birth']);
          if (dob != null) {
            formattedDob = DateFormat('dd.MM.yyyy').format(dob);
          }
        }

        String gender = 'Не указан';
        if (profile?['gender'] == 'male') gender = 'Мужской';
        if (profile?['gender'] == 'female') gender = 'Женский';

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
            title: const Text(
              'ПРОФИЛЬ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, size: 26, color: Colors.black),
                onPressed: provider.profileData == null
                    ? null
                    : () async {
                        final result = await context.push(
                          '/profile/edit',
                          extra: profile,
                        );

                        if (result == true && context.mounted) {
                          await context.push('/profile/edit', extra: profile);
                        }
                      },
              ),
            ],
          ),
          body: isLoading && provider.profileData == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: .6),
                                  Theme.of(context).primaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              backgroundColor: Colors.grey[300],
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () => provider.uploadAvatar(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 22,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
                            .trim()
                            .toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: .1),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 18,
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            'Дата рождения',
                            formattedDob.isNotEmpty
                                ? formattedDob
                                : 'Не указана',
                          ),
                          const Divider(),
                          _infoRow('Пол', gender),
                          const Divider(),
                          _infoRow('Телефон', profile?['phone'] ?? 'Не указан'),
                          const Divider(),
                          _infoRow('Email', provider.userEmail ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _menuButton(
                      context,
                      title: 'МОИ АДРЕСА',
                      icon: Icons.home_work_outlined,
                      onTap: () => context.push('/profile/addresses'),
                    ),
                    const SizedBox(height: 16),
                    _menuButton(
                      context,
                      title: 'ИЗБРАННОЕ',
                      icon: Icons.favorite_border,
                      onTap: () => context.push('/profile/favorites'),
                    ),
                    const SizedBox(height: 16),
                    _menuButton(
                      context,
                      title: 'МОИ ЗАКАЗЫ',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.push('/profile/orders'),
                    ),

                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async => supabase.auth.signOut(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'ВЫЙТИ',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

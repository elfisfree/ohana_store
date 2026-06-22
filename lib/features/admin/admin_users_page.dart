// lib/features/admin/admin_users_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/core/utils/app_notifications.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';
import 'package:go_router/go_router.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final ScrollController _scrollController = ScrollController();

  List<AdminUser> _allUsers = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  // Параметры фильтров
  String _searchQuery = '';
  String _selectedRoleFilter = 'all'; // Фильтр для отображения
  final String _sortBy = 'created_at'; // Сортировка

  @override
  void initState() {
    super.initState();
    _fetchUsers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasMore) {
          _loadMoreUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- ЗАГРУЗКА ДАННЫХ С УЧЕТОМ ФИЛЬТРОВ ---
  Future<void> _fetchUsers({bool isRefresh = true}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _allUsers = [];
        _hasMore = true;
      });
    }

    try {
      var query = supabase.from('admin_users_view').select();

      // Применяем фильтр по роли на уровне базы данных (эффективнее)
      if (_selectedRoleFilter != 'all') {
        query = query.eq('role', _selectedRoleFilter);
      }

      // Применяем поиск, если он есть
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'first_name.ilike.%$_searchQuery%,last_name.ilike.%$_searchQuery%,email.ilike.%$_searchQuery%',
        );
      }

      final response = await query
          .order(_sortBy, ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      final users = (response as List)
          .map((u) => AdminUser.fromJson(u))
          .toList();

      setState(() {
        if (isRefresh) {
          _allUsers = users;
        } else {
          _allUsers.addAll(users);
        }
        _isLoading = false;
        _isFetchingMore = false;
        if (users.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка загрузки: $e');
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  void _loadMoreUsers() {
    _currentPage++;
    _fetchUsers(isRefresh: false);
  }

  // --- ЛОГИКА ИЗМЕНЕНИЯ ДАННЫХ ---

  Future<void> _changeRole(AdminUser user, String newRole) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', user.id);
      AppNotifications.showSuccess(
        context,
        'Роль ${user.firstName} изменена на $newRole',
      );
      _fetchUsers(); // Перезагружаем список
    } catch (e) {
      AppNotifications.showError(context, 'Ошибка: $e');
    }
  }

  Future<void> _deleteUser(AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text(
          'УДАЛЕНИЕ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text('Удалить аккаунт ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ОТМЕНА'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.rpc(
          'delete_user_by_admin',
          params: {'target_user_id': user.id},
        );
        AppNotifications.showSuccess(context, 'Пользователь удален');
        _fetchUsers();
      } catch (e) {
        AppNotifications.showError(context, 'Ошибка: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и счетчик
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'УПРАВЛЕНИЕ КЛИЕНТАМИ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Всего в базе: ${_allUsers.length}${_hasMore ? "+" : ""}',
                      style: const TextStyle(
                        color: AdminColors.accentPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _buildFilterChips(),
              ],
            ),
            const SizedBox(height: 25),

            // Поиск
            TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                _searchQuery = val;
                _fetchUsers(); // Перезагружаем с первой страницы
              },
              decoration: InputDecoration(
                hintText: 'Поиск по имени, фамилии или email...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AdminColors.accentPurple,
                ),
                filled: true,
                fillColor: AdminColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Список
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AdminColors.accentPurple,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _allUsers.length + (_isFetchingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _allUsers.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _buildUserListItem(_allUsers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _filterChip('Все', 'all'),
        const SizedBox(width: 10),
        _filterChip('Админы', 'admin'),
        const SizedBox(width: 10),
        _filterChip('Курьеры', 'courier'),
        const SizedBox(width: 10),
        _filterChip('Сборщики', 'collector'),
      ],
    );
  }

  Widget _filterChip(String label, String role) {
    final bool isSelected = _selectedRoleFilter == role;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedRoleFilter = role);
          _fetchUsers();
        }
      },
      selectedColor: AdminColors.accentPurple,
      backgroundColor: AdminColors.card,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildUserListItem(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => context.push('/admin/users/${user.id}', extra: user),
        leading: CircleAvatar(
          backgroundColor: AdminColors.sidebar,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
              ? const Icon(Icons.person, color: Colors.white24)
              : null,
        ),
        title: Text(
          '${user.firstName} ${user.lastName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          user.email,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ВЫБОР РОЛИ
            DropdownButton<String>(
              value: user.role,
              dropdownColor: AdminColors.card,
              underline: const SizedBox(),
              style: const TextStyle(
                color: AdminColors.accentPurple,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('КЛИЕНТ')),
                DropdownMenuItem(value: 'admin', child: Text('АДМИН')),
                DropdownMenuItem(value: 'collector', child: Text('СБОРЩИК')),
                DropdownMenuItem(value: 'courier', child: Text('КУРЬЕР')),
              ],
              onChanged: (val) {
                if (val != null && val != user.role) _changeRole(user, val);
              },
            ),
            const SizedBox(width: 15),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _deleteUser(user),
            ),
          ],
        ),
      ),
    );
  }
}

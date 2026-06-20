// lib/features/admin/admin_users_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/admin_user_model.dart';

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
  bool _hasNextPage = true;
  final int _pageSize = 20;

  String _searchQuery = '';
  String _selectedRole = 'all';
  RangeValues _ageRange = const RangeValues(0, 100);
  final double _minYear = 2024;
  final double _maxYear = DateTime.now().year.toDouble();
  late RangeValues _yearRange;
  bool _isFilterVisible = true;

  Timer? _filterDebounce; // Для задержки запроса при вводе/слайдерах

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(_minYear, _maxYear);
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasNextPage) {
          _fetchMoreUsers();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterDebounce?.cancel();
    super.dispose();
  }

  // Метод для запуска фильтрации с задержкой 500мс
  void _onFilterChanged() {
    if (_filterDebounce?.isActive ?? false) _filterDebounce!.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _allUsers = [];
      _hasNextPage = true;
    });
    await _fetchMoreUsers();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchMoreUsers() async {
    if (_isFetchingMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final int from = _allUsers.length;
      final int to = from + _pageSize - 1;

      var query = supabase.from('admin_users_view').select();

      // 1. Поиск по тексту
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'first_name.ilike.%$_searchQuery%,last_name.ilike.%$_searchQuery%,email.ilike.%$_searchQuery%',
        );
      }

      // 2. Фильтр по роли
      if (_selectedRole != 'all') {
        query = query.eq('role', _selectedRole);
      }

      // 3. ФИЛЬТР ПО ВОЗРАСТУ (Конвертация возраста в даты рождения)
      final now = DateTime.now();
      // Те, кому сейчас X лет, родились между (сейчас - X-1 лет) и (сейчас - X лет)
      final DateTime birthDateStart = DateTime(
        now.year - _ageRange.end.toInt() - 1,
        now.month,
        now.day,
      );
      final DateTime birthDateEnd = DateTime(
        now.year - _ageRange.start.toInt(),
        now.month,
        now.day,
      );

      query = query
          .gte('date_of_birth', birthDateStart.toIso8601String())
          .lte('date_of_birth', birthDateEnd.toIso8601String());

      // 4. ФИЛЬТР ПО ГОДУ РЕГИСТРАЦИИ
      final DateTime regStart = DateTime(_yearRange.start.toInt(), 1, 1);
      final DateTime regEnd = DateTime(
        _yearRange.end.toInt(),
        12,
        31,
        23,
        59,
        59,
      );

      query = query
          .gte('created_at', regStart.toIso8601String())
          .lte('created_at', regEnd.toIso8601String());

      // 5. Выполнение с пагинацией
      final response = await query
          .range(from, to)
          .order('created_at', ascending: false);

      final newUsers = (response as List)
          .map((u) => AdminUser.fromJson(u))
          .toList();

      if (mounted) {
        setState(() {
          _allUsers.addAll(newUsers);
          _isFetchingMore = false;
          if (newUsers.length < _pageSize) {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  // --- ДАЛЕЕ UI ЧАСТЬ БЕЗ ИЗМЕНЕНИЙ В СТРУКТУРЕ, НО С ИСПРАВЛЕННЫМИ ВЫЗОВАМИ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 25),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AdminColors.accentBlue,
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                _allUsers.length + (_hasNextPage ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _allUsers.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              return _buildUserCard(_allUsers[index]);
                            },
                          ),
                  ),
                  if (_isFilterVisible) ...[
                    const SizedBox(width: 30),
                    SizedBox(width: 300, child: _buildFilterCard()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'БАЗА КЛИЕНТОВ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Найдено записей: ${_allUsers.length}${_hasNextPage ? "+" : ""}',
              style: const TextStyle(
                color: AdminColors.accentBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(
            _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _isFilterVisible = !_isFilterVisible),
        ),
      ],
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОИСК И ФИЛЬТРЫ',
            style: TextStyle(
              color: AdminColors.accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _onFilterChanged();
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Имя или email...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: AdminColors.sidebar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 25),
          _roleSection(),
          const SizedBox(height: 25),
          _buildSliderLabel(
            'ВОЗРАСТ',
            '${_ageRange.start.toInt()} - ${_ageRange.end.toInt()}',
          ),
          RangeSlider(
            values: _ageRange,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _ageRange = val);
              _onFilterChanged();
            },
          ),
          const SizedBox(height: 20),
          _buildSliderLabel(
            'ГОД РЕГИСТРАЦИИ',
            '${_yearRange.start.toInt()} - ${_yearRange.end.toInt()}',
          ),
          RangeSlider(
            values: _yearRange,
            min: _minYear,
            max: _maxYear,
            divisions: (_maxYear - _minYear).toInt() == 0
                ? 1
                : (_maxYear - _minYear).toInt(),
            activeColor: AdminColors.accentBlue,
            onChanged: (val) {
              setState(() => _yearRange = val);
              _onFilterChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _roleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'РОЛЬ',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            _roleChip('Все', 'all'),
            _roleChip('Клиент', 'user'),
            _roleChip('Админ', 'admin'),
            _roleChip('Сборщик', 'collector'),
            _roleChip('Курьер', 'courier'),
          ],
        ),
      ],
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: () => context.push('/admin/users/${user.id}', extra: user),
        leading: CircleAvatar(
          backgroundColor: AdminColors.sidebar,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.startsWith('http'))
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null)
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
          style: const TextStyle(color: Colors.white38),
        ),
        trailing: _buildRoleBadge(user.role),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String text;

    switch (role.toLowerCase()) {
      case 'admin':
        color = AdminColors.accentBlue;
        text = 'АДМИН';
        break;
      case 'collector':
        color = Colors.greenAccent;
        text = 'СБОРЩИК';
        break;
      case 'courier':
        color = Colors.orangeAccent;
        text = 'КУРЬЕР';
        break;
      default:
        color = Colors.white24;
        text = 'КЛИЕНТ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String label, String value) {
    final bool isSelected = _selectedRole == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedRole = value);
          _onFilterChanged();
        }
      },
      selectedColor: AdminColors.accentBlue,
      backgroundColor: AdminColors.sidebar,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white38),
      showCheckmark: false,
    );
  }
}

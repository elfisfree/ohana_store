// lib/features/admin/promocode_report_page.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:ohana_store/core/admin_theme.dart';
import 'package:ohana_store/main.dart';
import 'package:ohana_store/models/promocode_usage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PromocodeReportPage extends StatefulWidget {
  final String promocodeId;
  const PromocodeReportPage({super.key, required this.promocodeId});

  @override
  State<PromocodeReportPage> createState() => _PromocodeReportPageState();
}

class _PromocodeReportPageState extends State<PromocodeReportPage> {
  late Future<(int, List<PromocodeUsage>)> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _fetchReportData();
  }

  Future<(int, List<PromocodeUsage>)> _fetchReportData() async {
    try {
      final countResponse = await supabase
          .from('promocode_report_view')
          .count(CountOption.exact)
          .eq('promocode_id', widget.promocodeId);

      final usageListResponse = await supabase
          .from('promocode_report_view')
          .select()
          .eq('promocode_id', widget.promocodeId)
          .order('used_at', ascending: false)
          .limit(100);

      final totalUsages = countResponse;
      final usages = (usageListResponse as List)
          .map((u) => PromocodeUsage.fromJson(u))
          .toList();

      return (totalUsages, usages);
    } catch (e) {
      print('!!! ОШИБКА ЗАГРУЗКИ ОТЧЕТА: $e');
      throw Exception('Не удалось загрузить отчет');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text(
          'АНАЛИТИКА ПРОМОКОДА',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<(int, List<PromocodeUsage>)>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AdminColors.accentPurple),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final (totalUsages, usages) = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildStatHeader(totalUsages)],
                ),

                const SizedBox(height: 40),
                _buildUsageTable(usages),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatHeader(int total) {
    return Container(
      width: 300,
      height: 250,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AdminColors.accentPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ВСЕГО ИСПОЛЬЗОВАНО',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.greenAccent, size: 20),
              SizedBox(width: 5),
              Text(
                'Активная акция',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTable(List<PromocodeUsage> usages) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОСЛЕДНИЕ ТРАНЗАКЦИИ',
            style: TextStyle(
              color: AdminColors.accentPurple,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 25),
          if (usages.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Данные отсутствуют',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              children: [
                TableRow(
                  children: [
                    _tableHeader('ЗАКАЗ'),
                    _tableHeader('КЛИЕНТ'),
                    _tableHeader('ДАТА'),
                  ],
                ),
                ...usages.map(
                  (u) => TableRow(
                    children: [
                      _tableCell('#${u.orderId.substring(0, 8)}', isBold: true),
                      _tableCell(u.customerName ?? 'Аноним'),
                      _tableCell(
                        DateFormat('dd.MM.yyyy').format(u.usedAt.toLocal()),
                        isDim: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  //------------------конец графика
  Widget _tableHeader(String text) => Padding(
    padding: const EdgeInsets.all(15),
    child: Text(
      text,
      style: const TextStyle(
        color: AdminColors.accentPurple,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  Widget _tableCell(String text, {bool isBold = false, bool isDim = false}) =>
      Padding(
        padding: const EdgeInsets.all(15),
        child: Text(
          text,
          style: TextStyle(
            color: isDim ? Colors.white38 : Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
}

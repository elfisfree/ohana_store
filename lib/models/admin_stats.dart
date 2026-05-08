class AdminStats {
  final int totalOrders;
  final double totalRevenue;
  final int totalCustomers;
  final int pendingOrders;
  final double avgCheck; // <-- Новое
  final double revenueToday; // <-- Новое

  AdminStats({
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalCustomers,
    required this.pendingOrders,
    required this.avgCheck,
    required this.revenueToday,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalOrders: json['total_orders'] ?? 0,
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      totalCustomers: json['total_customers'] ?? 0,
      pendingOrders: json['pending_orders'] ?? 0,
      avgCheck: (json['avg_check'] as num).toDouble(),
      revenueToday: (json['revenue_today'] as num).toDouble(),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../utils/image_utils.dart';
import '../utils/transition_utils.dart';
import 'profile_page.dart';

class AdminPurchasesPage extends StatefulWidget {
  final int userId;
  final String userRole;

  const AdminPurchasesPage({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  State<AdminPurchasesPage> createState() => _AdminPurchasesPageState();
}

class _AdminPurchasesPageState extends State<AdminPurchasesPage> {
  static const Color _brandGreen = Color(0xFF56C900);

  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Order>> _loadOrders() {
    return OrderService.fetchAllOrders(
      userId: widget.userId,
      role: widget.userRole,
    );
  }

  int _totalQuantity(List<Order> orders) {
    return orders.fold(0, (sum, order) => sum + order.quantity);
  }

  int _totalMoney(List<Order> orders) {
    return orders.fold(0, (sum, order) => sum + order.totalPrice);
  }

  Map<int, List<Order>> _ordersByUser(List<Order> orders) {
    final grouped = <int, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(order.userId, () => []).add(order);
    }
    return grouped;
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = _loadOrders();
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: const Text('Compras de usuarios'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _brandGreen,
        child: FutureBuilder<List<Order>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.error_outline, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'No se pudieron cargar las compras: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final orders = snapshot.data ?? [];
            if (orders.isEmpty) {
              return const Center(
                child: Text('Todavia no hay compras registradas'),
              );
            }

            final grouped = _ordersByUser(orders);
            final userGroups = grouped.entries.toList()
              ..sort((a, b) {
                final latestA = a.value.first.createdAt;
                final latestB = b.value.first.createdAt;
                return latestB.compareTo(latestA);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: userGroups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SummaryCard(
                    orderCount: orders.length,
                    totalQuantity: _totalQuantity(orders),
                    totalMoney: _totalMoney(orders),
                  );
                }

                return _UserHistoryCard(orders: userGroups[index - 1].value);
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserHistoryCard extends StatelessWidget {
  final List<Order> orders;

  const _UserHistoryCard({required this.orders});

  int get _totalQuantity {
    return orders.fold(0, (sum, order) => sum + order.quantity);
  }

  int get _totalMoney {
    return orders.fold(0, (sum, order) => sum + order.totalPrice);
  }

  @override
  Widget build(BuildContext context) {
    final firstOrder = orders.first;
    final buyer = firstOrder.userName.isNotEmpty
        ? firstOrder.userName
        : 'Usuario ${firstOrder.userId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          buyer,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${orders.length} compra(s) | $_totalQuantity producto(s) | \$$_totalMoney',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          ...orders.map((order) => _OrderAdminCard(order: order)).toList(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('Ver perfil'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF56C900),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  fadeSlideRoute(
                    ProfilePage(
                      userId: firstOrder.userId,
                      userName: buyer,
                      userEmail: firstOrder.userEmail,
                      userRole: 'cliente',
                      showLogout: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int orderCount;
  final int totalQuantity;
  final int totalMoney;

  const _SummaryCard({
    required this.orderCount,
    required this.totalQuantity,
    required this.totalMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBEF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDEABD)),
      ),
      child: Row(
        children: [
          Expanded(child: _Metric(label: 'Compras', value: '$orderCount')),
          Expanded(child: _Metric(label: 'Productos', value: '$totalQuantity')),
          Expanded(child: _Metric(label: 'Total', value: '\$$totalMoney')),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _OrderAdminCard extends StatelessWidget {
  final Order order;

  const _OrderAdminCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final buyer =
        order.userName.isNotEmpty ? order.userName : 'Usuario ${order.userId}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: buildProductImage(
                order.productImageUrl,
                order.productImageUrl,
                fit: BoxFit.cover,
                placeholder: const Icon(Icons.inventory_2_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buyer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order.userEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  order.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cantidad: ${order.quantity}  |  Total: \$${order.totalPrice}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

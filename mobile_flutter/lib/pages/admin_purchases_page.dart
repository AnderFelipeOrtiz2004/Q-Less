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

class _AdminPurchasesPageState extends State<AdminPurchasesPage>
    with SingleTickerProviderStateMixin {
  static const Color _brandGreen = Color(0xFF56C900);

  late TabController _tabController;
  late Future<List<Order>> _pendingFuture;
  late Future<List<Order>> _allFuture;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    _pendingFuture = OrderService.fetchPendingOrders(
      userId: widget.userId,
      role: widget.userRole,
    );
    _allFuture = OrderService.fetchAllOrders(
      userId: widget.userId,
      role: widget.userRole,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_pendingFuture, _allFuture]);
  }

  Future<void> _approve(Order order) async {
    await _handleAction(order, approve: true);
  }

  Future<void> _reject(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar compra'),
        content: Text(
          '¿Rechazar la solicitud de ${order.productName} (x${order.quantity})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _handleAction(order, approve: false);
  }

  Future<void> _handleAction(Order order, {required bool approve}) async {
    if (_processingIds.contains(order.id)) return;
    setState(() => _processingIds.add(order.id));

    final result = approve
        ? await OrderService.approveOrder(
            adminUserId: widget.userId,
            role: widget.userRole,
            orderId: order.id,
          )
        : await OrderService.rejectOrder(
            adminUserId: widget.userId,
            role: widget.userRole,
            orderId: order.id,
          );

    if (!mounted) return;
    setState(() => _processingIds.remove(order.id));

    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (ok
                  ? (approve
                      ? 'Compra aprobada. Se envió el código al correo del usuario.'
                      : 'Compra rechazada')
                  : 'No se pudo procesar'),
        ),
        backgroundColor: ok ? _brandGreen : Colors.red,
      ),
    );
    if (ok) await _refresh();
  }

  Future<void> _enablePurchases(Order order) async {
    final result = await OrderService.toggleUserPurchases(
      adminUserId: widget.userId,
      role: widget.userRole,
      targetUserId: order.userId,
      enabled: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Compras habilitadas'),
        backgroundColor: result['success'] == true ? _brandGreen : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: const Text('Gestión de compras'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingTab(
            future: _pendingFuture,
            processingIds: _processingIds,
            onRefresh: _refresh,
            onApprove: _approve,
            onReject: _reject,
            onEnablePurchases: _enablePurchases,
          ),
          _HistoryTab(
            future: _allFuture,
            onRefresh: _refresh,
          ),
        ],
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  final Future<List<Order>> future;
  final Set<int> processingIds;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Order) onApprove;
  final Future<void> Function(Order) onReject;
  final Future<void> Function(Order) onEnablePurchases;

  const _PendingTab({
    required this.future,
    required this.processingIds,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
    required this.onEnablePurchases,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF56C900),
      child: FutureBuilder<List<Order>>(
        future: future,
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
                  'No se pudieron cargar pendientes: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'No hay compras pendientes de revisión',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _PendingOrderCard(
                order: order,
                busy: processingIds.contains(order.id),
                onApprove: () => onApprove(order),
                onReject: () => onReject(order),
                onEnablePurchases: () => onEnablePurchases(order),
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  final Order order;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEnablePurchases;

  const _PendingOrderCard({
    required this.order,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onEnablePurchases,
  });

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
        border: Border.all(color: const Color(0xFFFFE082)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions, color: Color(0xFFE8A838)),
              const SizedBox(width: 8),
              const Text(
                'Pendiente de aprobación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (order.userEmail.isNotEmpty)
                      Text(
                        order.userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      order.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cantidad: ${order.quantity}  |  Total: \$${order.totalPrice}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF56C900),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aprobar compra'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onEnablePurchases,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Habilitar compras al usuario'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final Future<List<Order>> future;
  final Future<void> Function() onRefresh;

  const _HistoryTab({
    required this.future,
    required this.onRefresh,
  });

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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF56C900),
      child: FutureBuilder<List<Order>>(
        future: future,
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
              child: Text('Todavía no hay compras registradas'),
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
          ...orders.map((order) => _OrderAdminCard(order: order)),
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

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pendiente') return const Color(0xFFE8A838);
    if (s == 'rechazada' || s == 'rechazado') return Colors.red;
    return const Color(0xFF56C900);
  }

  @override
  Widget build(BuildContext context) {
    final buyer =
        order.userName.isNotEmpty ? order.userName : 'Usuario ${order.userId}';
    final statusColor = _statusColor(order.status);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        buyer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/carrito_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';
import '../services/favorites_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';
import '../utils/transition_utils.dart';
import '../widgets/quantity_input.dart';
import 'admin_purchases_page.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'chatbot_page.dart';
import 'my_purchases_page.dart';
import 'product_detail_page.dart';
import 'products_page.dart';
import 'profile_page.dart';

/// Home page displayed after successful login/registration
class HomePage extends StatefulWidget {
  final int? userId;
  final String? userName;
  final String userRole;

  const HomePage({
    super.key,
    this.userId,
    this.userName,
    this.userRole = 'aprendiz',
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _brandGreen = Color(0xFF56C900);
  static const Color _pageGray = Color(0xFFE6E6E6);

  List<Product> products = [];
  List<Product> _bannerProducts = [];
  List<CartItem> _cartItems = [];
  String _displayName = 'Usuario';
  Timer? _bannerTimer;
  final PageController _bannerController = PageController();
  final Map<int, Timer> _reservationTimers = {};

  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  bool _isLoading = true;
  bool _initialLoadDone = false;
  String _errorMessage = '';
  int _bannerIndex = 0;
  Set<int> _favoriteIds = {};

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName ?? 'Usuario';
    _loadProducts();
    _loadCartFromServer();
    _loadFavoriteIds();
    _startBannerTimer();
  }

  int get _uid => widget.userId ?? 0;

  Future<void> _loadFavoriteIds() async {
    if (_uid <= 0) return;
    final ids = await FavoritesService.getFavoriteIds(userId: _uid);
    if (mounted) setState(() => _favoriteIds = ids);
  }

  Future<void> _toggleFavorite(Product product) async {
    if (_uid <= 0) return;
    SoundService.playClick();
    final nowFav = await FavoritesService.toggleFavorite(
      userId: _uid,
      productId: product.id,
    );
    if (!mounted) return;
    setState(() {
      if (nowFav) {
        _favoriteIds.add(product.id);
      } else {
        _favoriteIds.remove(product.id);
      }
    });
  }

  void _showOutOfStockMessage(String productName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ya no hay stock de "$productName".'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadCartFromServer() async {
    final userId = widget.userId;
    if (userId == null || userId <= 0) return;

    try {
      final response = await CarritoService.obtenerCarrito(userId: userId);
      if (!mounted || response['status'] != 'success') return;

      final list = response['data'] as List<dynamic>? ?? [];
      final restored = <CartItem>[];

      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final productId = int.tryParse(raw['product_id']?.toString() ?? '') ?? 0;
        if (productId <= 0) continue;

        final product = Product(
          id: productId,
          nombre: raw['nombre']?.toString() ?? 'Producto',
          descripcion: raw['descripcion']?.toString() ?? '',
          categoria: raw['categoria']?.toString() ?? 'General',
          precio: int.tryParse(raw['precio']?.toString() ?? '') ?? 0,
          stock: int.tryParse(raw['stock']?.toString() ?? '') ?? 0,
          availableStock: int.tryParse(raw['stock']?.toString() ?? '') ?? 0,
          imageUrl: raw['image_url']?.toString() ?? '',
          imagePath: raw['image_path']?.toString() ?? '',
        );

        restored.add(
          CartItem(
            product: product,
            quantity: int.tryParse(raw['quantity']?.toString() ?? '') ?? 1,
            reservationId: int.tryParse(raw['reservation_id']?.toString() ?? ''),
            reservationExpiresAt:
                DateTime.tryParse(raw['expires_at']?.toString() ?? ''),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _cartItems = restored;
      });
    } catch (_) {
      // Mantener carrito local si falla la red.
    }
  }

  Future<void> _refreshUserDisplayName() async {
    final userId = widget.userId;
    if (userId == null || userId <= 0) return;
    try {
      final user = await UserService.fetchUser(userId: userId);
      if (mounted) {
        setState(() => _displayName = user.nombre);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    for (final t in _reservationTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _bannerProducts.length < 2) return;
      final nextIndex = (_bannerIndex + 1) % _bannerProducts.length;
      _goToBanner(nextIndex);
    });
  }

  void _goToBanner(int index) {
    if (_bannerProducts.isEmpty) return;
    final safeIndex = index % _bannerProducts.length;

    setState(() {
      _bannerIndex = safeIndex;
    });

    if (_bannerController.hasClients) {
      _bannerController.animateToPage(
        safeIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<Product> _selectBannerProducts(List<Product> source) {
    if (source.isEmpty) return [];
    final random = Random();
    final items = List<Product>.from(source);
    items.shuffle(random);
    return items.take(min(3, items.length)).toList();
  }

  int get _cartCount {
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _loadProducts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final loadedProducts = await ProductService.fetchProducts();
      if (!mounted) return;

      if (silent && _initialLoadDone) {
        _applyProductUpdateQuietly(loadedProducts);
        return;
      }

      setState(() {
        products = loadedProducts;
        _bannerProducts = _selectBannerProducts(loadedProducts);
        _bannerIndex = 0;
        _mergeCartWithProducts(loadedProducts);
        _errorMessage = '';
        _isLoading = false;
        _initialLoadDone = true;
      });
      if (_bannerController.hasClients) {
        _bannerController.jumpToPage(0);
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los productos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyProductUpdateQuietly(List<Product> loadedProducts) {
    var changed = false;
    final byId = {for (final p in loadedProducts) p.id: p};

    for (var i = 0; i < products.length; i++) {
      final fresh = byId[products[i].id];
      if (fresh == null) continue;
      if (fresh.availableStock != products[i].availableStock ||
          fresh.stock != products[i].stock ||
          fresh.precio != products[i].precio) {
        products[i] = fresh;
        changed = true;
      }
    }

    for (var i = 0; i < _cartItems.length; i++) {
      final fresh = byId[_cartItems[i].product.id];
      if (fresh != null && fresh.id == _cartItems[i].product.id) {
        _cartItems[i] = CartItem(
          product: fresh,
          quantity: _cartItems[i].quantity,
          reservationId: _cartItems[i].reservationId,
          reservationExpiresAt: _cartItems[i].reservationExpiresAt,
        );
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  void _mergeCartWithProducts(List<Product> loadedProducts) {
    _cartItems = _cartItems.map((cartItem) {
      final freshProduct = loadedProducts.firstWhere(
        (product) => product.id == cartItem.product.id,
        orElse: () => cartItem.product,
      );
      return CartItem(
        product: freshProduct,
        quantity: cartItem.quantity,
        reservationId: cartItem.reservationId,
        reservationExpiresAt: cartItem.reservationExpiresAt,
      );
    }).toList();
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.nombre.toLowerCase().contains(query) ||
          product.descripcion.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _navigateTo(Widget page, {bool refreshOnReturn = false}) async {
    await Navigator.of(context).push(fadeSlideRoute(page));

    if (refreshOnReturn) {
      _loadProducts(silent: true);
      _loadFavoriteIds();
    }
  }

  void _openSearch() {
    setState(() {
      _searchActive = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchController.clear();
    });
  }

  void _addToCart(Product product, int quantity) {
    if (_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los administradores no pueden comprar productos'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (product.availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.nombre} está agotado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (quantity > product.availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solo hay ${product.availableStock} disponibles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ask server to reserve items
    ProductService.reserveProduct(
      userId: widget.userId ?? 1,
      productId: product.id,
      quantity: quantity,
    ).then((resp) {
      if (!mounted) return;
      if (resp['status'] == 'success' && resp['data'] != null) {
        final rid = int.tryParse(resp['data']['id'].toString()) ?? 0;
        DateTime? expiresAt;
        try {
          expiresAt = DateTime.parse(resp['data']['expires_at']);
        } catch (_) {}

        setState(() {
          _cartItems.add(
            CartItem(
              product: product,
              quantity: quantity,
              reservationId: rid,
              reservationExpiresAt: expiresAt,
            ),
          );

          final pIndex = products.indexWhere((p) => p.id == product.id);
          if (pIndex >= 0) {
            final old = products[pIndex];
            final reservedStock =
                int.tryParse(resp['data']['available_stock']?.toString() ?? '');
            final newAvailable = reservedStock ??
                max(0, old.availableStock - quantity);
            products[pIndex] = old.copyWith(
              availableStock: newAvailable,
            );
          }
        });

        // schedule auto-release
        final now = DateTime.now();
        final dur = expiresAt != null ? expiresAt.difference(now) : const Duration(minutes: 5);
        final timer = Timer(dur.isNegative ? const Duration(minutes: 5) : dur, () async {
          if (rid > 0) {
            await ProductService.releaseReservation(reservationId: rid);
          }
          if (!mounted) return;
          setState(() {
            _cartItems.removeWhere((c) => c.reservationId == rid);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reserva de ${product.nombre} expirada y liberada'),
              backgroundColor: Colors.orange,
            ),
          );
          _reservationTimers.remove(rid);
          _loadProducts(silent: true);
        });

        if (rid > 0) _reservationTimers[rid] = timer;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.nombre} reservado ($quantity)'),
            backgroundColor: _brandGreen,
            duration: const Duration(seconds: 2),
          ),
        );

        final remainingAfterReserve =
            int.tryParse(resp['data']['available_stock']?.toString() ?? '') ??
                max(0, product.availableStock - quantity);
        if (remainingAfterReserve <= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock bajo: quedan $remainingAfterReserve'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        _loadProducts(silent: true);
      } else {
        final message = resp['message'] ?? 'No se pudo reservar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    });
  }

  void _showCart() {
    Navigator.of(context).push(
      fadeSlideRoute(
        CartPage(
          userId: widget.userId ?? 1,
          userName: _displayName,
          cartItems: _cartItems,
          onCartUpdate: (items) {
            setState(() {
              _cartItems = items;
            });
            _loadProducts(silent: true);
          },
          onContinueShopping: () => _loadProducts(silent: true),
          onPurchaseComplete: () {
            _loadProducts(silent: true);
            // Ir a Mis Compras
            Navigator.of(context).push(
              fadeSlideRoute(
                MyPurchasesPage(
                  userId: widget.userId ?? 1,
                  userName: _displayName,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showBuyDialog(Product product) {
    if (product.availableStock <= 0) {
      _showOutOfStockMessage(product.nombre);
      return;
    }
    int qty = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.nombre,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                QuantityInput(
                  value: qty,
                  max: product.availableStock,
                  onChanged: (v) => setState(() => qty = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: \$${product.precio * qty}'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: product.availableStock > 0
                        ? () {
                            SoundService.playClick();
                            _addToCart(product, qty);
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _brandGreen),
                    child: Text('Comprar ($qty)'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = _filteredProducts;

    return Scaffold(
      backgroundColor: _pageGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildIconNavigation(),
            if (_searchActive) _buildSearchField(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                color: kBrandGreen,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildBanner()),
                    SliverToBoxAdapter(child: _buildDots()),
                    SliverToBoxAdapter(child: _buildFeaturedTitle()),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (_isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage.isNotEmpty)
                      SliverToBoxAdapter(child: _buildErrorState())
                    else if (visibleProducts.isEmpty)
                      SliverToBoxAdapter(child: _buildEmptyState())
                    else
                      SliverList.builder(
                        itemCount: visibleProducts.length,
                        itemBuilder: (context, index) {
                          final product = visibleProducts[index];
                          return KeyedSubtree(
                            key: ValueKey<int>(product.id),
                            child: _buildProductCard(product),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: _brandGreen,
              foregroundColor: Colors.white,
              onPressed: () => _navigateTo(
                ProductsPage(
                  userId: widget.userId ?? 1,
                  userRole: widget.userRole,
                ),
                refreshOnReturn: true,
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin'),
            )
          : null,
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _brandGreen,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Q-LESS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          _buildHeaderButton(
            icon: Icons.person_outline,
            tooltip: 'Perfil',
            onTap: () async {
              await _navigateTo(
                ProfilePage(
                  userId: widget.userId,
                  userName: _displayName,
                  userRole: widget.userRole,
                  showLogout: true,
                ),
              );
              await _refreshUserDisplayName();
            },
          ),
          const SizedBox(width: 7),
          _buildHeaderButton(
            icon: _searchActive ? Icons.close : Icons.search,
            tooltip: _searchActive ? 'Cerrar busqueda' : 'Buscar',
            onTap: _searchActive ? _closeSearch : _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, color: Colors.grey[500], size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildIconNavigation() {
    return Container(
      height: 42,
      color: _brandGreen,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(
            icon: Icons.home,
            label: 'Inicio',
            onTap: () {
              _closeSearch();
            },
          ),
          _buildNavIcon(
            icon: Icons.inventory_2_outlined,
            label: 'Productos',
            onTap: () => _navigateTo(
              ProductsPage(
                userId: widget.userId ?? 1,
                userRole: widget.userRole,
              ),
              refreshOnReturn: true,
            ),
          ),
          _buildNavIcon(
            icon: Icons.favorite_outline,
            label: 'Favoritos',
            onTap: () async {
              await _navigateTo(
                FavoritesPage(
                  userId: widget.userId ?? 1,
                  userRole: widget.userRole,
                  onAddToCart: _addToCart,
                ),
              );
              _loadFavoriteIds();
            },
          ),
          _buildNavIcon(
            icon: Icons.chat_outlined,
            label: 'Chat',
            onTap: () => _navigateTo(
              ChatbotPage(
                userRole: widget.userRole,
                userId: widget.userId ?? 0,
              ),
            ),
          ),
          _isAdmin
              ? _buildNavIcon(
                  icon: Icons.receipt_long_outlined,
                  label: 'Compras',
                  onTap: () => _navigateTo(
                    AdminPurchasesPage(
                      userId: widget.userId ?? 1,
                      userRole: widget.userRole,
                    ),
                  ),
                )
              : _buildNavIcon(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Carrito',
                  onTap: _showCart,
                ),
        ],
      ),
    );
  }

  Widget _buildNavIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: () {
          SoundService.playClick();
          onTap();
        },
        icon: Icon(icon, color: Colors.white, size: 27),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Buscar productos',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                ),
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final banners = _bannerProducts.isNotEmpty
        ? _bannerProducts
        : _selectBannerProducts(products);

    if (banners.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFD7D7D7),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Colors.black38,
          size: 48,
        ),
      );
    }

    final product = banners[_bannerIndex % banners.length];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (banners.length < 2) return;
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < 0) {
          _goToBanner(_bannerIndex + 1);
        } else if (velocity > 0) {
          _goToBanner(_bannerIndex - 1 + banners.length);
        }
      },
      onTap: () => _navigateTo(
        ProductDetailPage(
          product: product,
          userId: widget.userId ?? 1,
          userRole: widget.userRole,
          onAddToCart: _addToCart,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: Stack(
              key: ValueKey<int>(product.id),
              fit: StackFit.expand,
              children: [
                buildProductImage(
                  product.imagePath,
                  product.imageUrl,
                  fit: BoxFit.cover,
                  width: MediaQuery.sizeOf(context).width - 16,
                  height: 200,
                  context: context,
                  placeholder: Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.black38,
                      size: 48,
                    ),
                  ),
                ),
              // Gradiente oscuro en la parte inferior para mejorar legibilidad
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              // Información del producto
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${product.precio} Pesos',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Container(
      color: const Color(0xFFD7D7D7),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_bannerProducts.length, (index) {
          final selected = index == _bannerIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 10 : 8,
            height: selected ? 10 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _brandGreen : Colors.grey[400],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeaturedTitle() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFD7D7D7),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _searchController.text.trim().isEmpty ? 'Destacados' : 'Resultados',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(28),
      color: Colors.white,
      child: const Text(
        'No encontramos productos con esa busqueda.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54, fontSize: 16),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(backgroundColor: _brandGreen),
            child: const Text(
              'Reintentar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final outOfStock = product.availableStock <= 0;
    final isFavorite = _favoriteIds.contains(product.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 18),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: !outOfStock
            ? const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : [],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateTo(
          ProductDetailPage(
            product: product,
            userId: widget.userId ?? 1,
            userRole: widget.userRole,
            onAddToCart: _addToCart,
          ),
        ).then((_) => _loadFavoriteIds()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outOfStock)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya no hay stock de este producto',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
              child: Container(
                width: 166,
                height: 154,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDADADA), width: 6),
                ),
                child: buildProductImage(
                  product.imagePath,
                  product.imageUrl,
                  fit: BoxFit.contain,
                  width: 150,
                  height: 138,
                  context: context,
                  placeholder: const Icon(
                    Icons.inventory_2_outlined,
                    size: 54,
                    color: Colors.black38,
                  ),
                ),
              ),
            ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleFavorite(product),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              product.nombre,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${product.precio} Pesos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _navigateTo(
                    ProductDetailPage(
                      product: product,
                      userId: widget.userId ?? 1,
                      userRole: widget.userRole,
                      onAddToCart: _addToCart,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0E0E0),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(82, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Ver más',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Disponible: ${product.availableStock}',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
                const Spacer(),
                Badge(
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                    child: Text(
                      _cartCount.toString(),
                      key: ValueKey<int>(_cartCount),
                    ),
                  ),
                  backgroundColor: _brandGreen,
                  child: IconButton(
                    onPressed: outOfStock
                        ? () => _showOutOfStockMessage(product.nombre)
                        : () => _showBuyDialog(product),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    color: _brandGreen,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

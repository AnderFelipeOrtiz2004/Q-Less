import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../utils/image_utils.dart';
import '../utils/transition_utils.dart';
import '../widgets/index.dart';
import 'product_detail_page.dart';

class ProductsPage extends StatefulWidget {
  final int userId;
  final String userRole;

  const ProductsPage({
    super.key,
    this.userId = 1,
    this.userRole = 'aprendiz',
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const Color _brandGreen = Color(0xFF3EC13B);

  String selectedCategory = 'Todos';
  List<String> categories = [
    'Todos',
    'Maquetas',
    'Papeleria',
    'Tecnologia',
    'Lapices',
    'Hojas',
    'Tijeras',
    'Reglas',
  ];

  List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final products = await ProductService.fetchProducts();
      if (!mounted) return;

      final normalizedCategoryMap = <String, String>{};
      for (final product in products) {
        final rawCategory = product.categoria.trim();
        if (rawCategory.isEmpty || rawCategory.toLowerCase() == 'todos') continue;
        final normalizedKey = rawCategory.toLowerCase();
        normalizedCategoryMap.putIfAbsent(normalizedKey, () => rawCategory);
      }

      setState(() {
        _products = products;
        categories = ['Todos', ...normalizedCategoryMap.values];
        if (!categories.contains(selectedCategory)) {
          selectedCategory = 'Todos';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar productos: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openProductForm([Product? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ProductFormDialog(
        product: product,
        userId: widget.userId,
        userRole: widget.userRole,
      ),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar producto'),
        content: Text('Quieres borrar "${product.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await ProductService.deleteProduct(
      productId: product.id,
      userId: widget.userId,
      role: widget.userRole,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']),
        backgroundColor: response['success'] == true ? _brandGreen : Colors.red,
      ),
    );

    if (response['success'] == true) {
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Administrar productos' : 'Productos'),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        color: _brandGreen,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  items: categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedCategory = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: _brandGreen,
              foregroundColor: Colors.white,
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Crear'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    final listaProductosCompleta = _products;
    final productosFiltrados = selectedCategory == 'Todos'
      ? listaProductosCompleta
      : listaProductosCompleta.where((producto) {
        final catProducto = producto.categoria.toString();
        return catProducto.trim().toLowerCase() == selectedCategory.trim().toLowerCase();
        }).toList();

    if (productosFiltrados.isEmpty) {
      return const Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: productosFiltrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final product = productosFiltrados[index];
        return FadeSlideEntry(
          duration: Duration(milliseconds: 260 + (index % 6) * 25),
          verticalOffset: 24,
          child: HoverElevatedCard(
            borderRadius: BorderRadius.circular(16),
            child: _ProductCard(
              product: product,
              isAdmin: _isAdmin,
              userId: widget.userId,
              userRole: widget.userRole,
              onEdit: () => _openProductForm(product),
              onDelete: () => _deleteProduct(product),
              onRefresh: () => _loadProducts(),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isAdmin;
  final int userId;
  final String userRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRefresh;

  const _ProductCard({
    required this.product,
    required this.isAdmin,
    required this.userId,
    required this.userRole,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
            BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: Hero(
              tag: 'product-image-${product.id}',
              child: buildProductImage(
                product.imagePath,
                product.imageUrl,
                width: 112,
                height: 126,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: 112,
                  height: 126,
                  color: Colors.grey[200],
                  child: const Icon(Icons.inventory_2_outlined),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${product.precio} Pesos',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3EC13B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${product.availableStock}',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  if (product.availableStock == 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Agotado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                  if (product.availableStock > 0 && product.availableStock <= 3) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'Stock bajo: ${product.availableStock}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Borrar'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // For regular users show action buttons to view details / buy
                  if (!isAdmin) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                                  fadeSlideRoute(
                                    ProductDetailPage(
                                      product: product,
                                      userId: userId,
                                      userRole: userRole,
                                      onAddToCart: (p, qty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${p.nombre} agregado al carrito ($qty)'),
                                            backgroundColor:
                                                const Color(0xFF3EC13B),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                    .then((_) {
                                  if (onRefresh != null) onRefresh!();
                                });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Ver más'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final Product? product;
  final int userId;
  final String userRole;

  const _ProductFormDialog({
    this.product,
    required this.userId,
    required this.userRole,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  static const Color _brandGreen = Color(0xFF3EC13B);
  static const List<String> _defaultCategories = [
    'Cuadernos',
    'Libros',
    'Lapices',
    'Esferos',
    'Marcadores',
    'Borradores',
    'Carpetas',
    'Papeles',
    'Pegantes',
    'Tijeras',
    'Otros',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imagePathController;
  late final TextEditingController _newCategoryController;

  late List<String> _categories;
  late String _selectedCategory;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isSaving = false;
  bool _showNewCategoryField = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _categories = List<String>.from(_defaultCategories);

    final product = widget.product;
    _nameController = TextEditingController(text: product?.nombre ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.precio.toString(),
    );
    _stockController = TextEditingController(
      text: product == null ? '' : product.stock.toString(),
    );
    _descriptionController =
        TextEditingController(text: product?.descripcion ?? '');
    _imagePathController = TextEditingController(
      text: product?.imagePath.isNotEmpty == true
          ? product!.imagePath
          : product?.imageUrl ?? '',
    );
    _categoryController = TextEditingController(text: product?.categoria ?? '');
    _newCategoryController = TextEditingController();

    _selectedCategory = product?.categoria ?? _categories.first;
    if (!_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _imagePathController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final newCategory = _newCategoryController.text.trim();
    if (newCategory.isEmpty) return;

    setState(() {
      if (!_categories.contains(newCategory)) {
        _categories.add(newCategory);
      }
      _selectedCategory = newCategory;
      _newCategoryController.clear();
      _showNewCategoryField = false;
    });
  }

  Future<void> _pickLocalImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = image.name;
      _imagePathController.text = image.path;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedImagePath = _imagePathController.text.trim();
    if (_pickedImageBytes == null && selectedImagePath.startsWith('blob:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona de nuevo la imagen local del producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

final parsedStock = int.parse(_stockController.text.trim());
      final product = Product(
        id: widget.product?.id ?? 0,
        nombre: _nameController.text.trim(),
        descripcion: _descriptionController.text.trim(),
        categoria: _selectedCategory,
        precio: int.parse(_priceController.text.trim()),
        stock: parsedStock,
        availableStock: parsedStock,
      imageUrl: selectedImagePath,
      imagePath: selectedImagePath,
      userId: widget.userId,
    );

    final response = _isEditing
        ? await ProductService.updateProduct(
            product: product,
            userId: widget.userId,
            role: widget.userRole,
            imageBytes: _pickedImageBytes,
            imageFileName: _pickedImageName,
          )
        : await ProductService.createProduct(
            product: product,
            userId: widget.userId,
            role: widget.userRole,
            imageBytes: _pickedImageBytes,
            imageFileName: _pickedImageName,
          );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message']),
        backgroundColor: response['success'] == true ? _brandGreen : Colors.red,
      ),
    );

    if (response['success'] == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Editar producto' : 'Crear producto',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabeledField(
                  label: 'Nombre de producto',
                  child: TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Ingresa el nombre'),
                    validator: _required,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  label: 'Categoría',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: _inputDecoration('Selecciona categoría'),
                        items: _categories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              _showNewCategoryField = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showNewCategoryField = !_showNewCategoryField;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar categoría'),
                      ),
                      if (_showNewCategoryField) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newCategoryController,
                                decoration: _inputDecoration('Nueva categoría'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.check, color: _brandGreen),
                              onPressed: _addCategory,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  label: 'Precio del producto',
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Ej: 25000'),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  label: 'Cantidad de producto en stock',
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Ej: 50'),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  label: 'Descripción del producto',
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration('Describe el producto'),
                    minLines: 3,
                    maxLines: 5,
                    validator: _required,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  label: 'Imágenes del producto',
                  child: Column(
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100],
                        ),
                        child: _pickedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _pickedImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _imagePathController.text.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: buildProductImage(
                                      _imagePathController.text,
                                      _imagePathController.text,
                                      fit: BoxFit.cover,
                                      placeholder: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No se pudo cargar la imagen',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickLocalImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _pickedImageName ?? 'Seleccionar imagen local',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _imagePathController,
                        readOnly: true,
                        decoration: _inputDecoration('Imagen seleccionada'),
                        validator: _required,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black87,
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'Editar' : 'Crear producto',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _positiveNumber(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'Ingresa un número válido';
    }
    return null;
  }
}

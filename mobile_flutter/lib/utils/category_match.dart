/// Flexible category matching (same logic as web Angular category-match.ts).
bool productMatchesCategory(String productCategory, String selectedCategory) {
  if (selectedCategory.isEmpty || selectedCategory == 'Todos') {
    return true;
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  const aliases = <String, List<String>>{
    'cuadernos y libretas': ['cuaderno', 'libreta', 'cuadernos', 'libretas'],
    'lapices y marcadores': [
      'lapiz',
      'lapices',
      'marcador',
      'marcadores',
      'esfero',
      'esferos',
      'escritura',
    ],
    'cartulinas y hojas': ['cartulina', 'cartulinas', 'hoja', 'hojas', 'papel'],
    'herramientas escolares': [
      'herramienta',
      'herramientas',
      'tijera',
      'tijeras',
      'regla',
      'pegante',
    ],
  };

  final product = normalize(productCategory);
  final selected = normalize(selectedCategory);

  if (product.isEmpty) {
    return false;
  }

  if (product.contains(selected) || selected.contains(product)) {
    return true;
  }

  final selectedAliases = aliases[selected] ?? [];
  if (selectedAliases.any((term) => product.contains(normalize(term)))) {
    return true;
  }

  final words = selected.split(RegExp(r'\s+')).where((w) => w.length > 3);
  return words.any((word) => product.contains(word));
}

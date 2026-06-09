const CATEGORY_ALIASES: Record<string, string[]> = {
  'cuadernos y libretas': ['cuaderno', 'libreta', 'cuadernos', 'libretas'],
  'lapices y marcadores': [
    'lapiz',
    'lápiz',
    'lapices',
    'lápices',
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

export function productMatchesCategory(
  productCategory: string,
  selectedCategory: string
): boolean {
  if (!selectedCategory || selectedCategory === 'Todos') {
    return true;
  }

  const normalize = (value: string) =>
    value
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .trim();

  const product = normalize(productCategory || '');
  const selected = normalize(selectedCategory);

  if (!product) {
    return false;
  }

  if (product.includes(selected) || selected.includes(product)) {
    return true;
  }

  const aliases = CATEGORY_ALIASES[selected] ?? [];
  if (aliases.some((term) => product.includes(normalize(term)))) {
    return true;
  }

  const words = selected.split(/\s+/).filter((word) => word.length > 3);
  return words.some((word) => product.includes(word));
}

const Set<String> kServiceCategories = <String>{
  'plumbing',
  'electrical',
  'hvac',
  'carpentry',
  'appliance',
  'handyman',
  'renovation',
  'painting',
  'flooring',
  'drywall',
  'roofing',
  'cleaning',
  'pest-control',
  'landscaping',
  'installation',
  'other',
};

const Map<String, String> _serviceCategoryAliases = <String, String>{
  'ac': 'hvac',
  'ac-maintenance': 'hvac',
  'air-conditioning': 'hvac',
  'appliance-repair': 'appliance',
  'pest-control': 'pest-control',
};

String normalizeServiceCategory(String? value) {
  final normalized =
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  final aliased = _serviceCategoryAliases[normalized] ?? normalized;
  return kServiceCategories.contains(aliased) ? aliased : '';
}

String serviceCategoryLabel(String category) {
  final normalized = normalizeServiceCategory(category);
  if (normalized.isEmpty) return 'Service';
  if (normalized == 'hvac') return 'HVAC';
  return normalized
      .split('-')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

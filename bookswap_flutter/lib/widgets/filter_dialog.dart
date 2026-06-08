import 'package:flutter/material.dart';

class FilterDialog extends StatefulWidget {
  final Map<String, List<String>> filterOptions;
  final Map<String, Set<String>> selectedFilters;
  final Function(Map<String, Set<String>>) onApplyFilters;

  const FilterDialog({
    super.key,
    required this.filterOptions,
    required this.selectedFilters,
    required this.onApplyFilters,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Map<String, Set<String>> _localFilters;

  @override
  void initState() {
    super.initState();
    // Create a copy of selected filters for local manipulation
    _localFilters = widget.selectedFilters.map(
      (key, value) => MapEntry(key, Set<String>.from(value)),
    );
  }

  void _toggleFilter(String category, String value) {
    setState(() {
      if (!_localFilters.containsKey(category)) {
        _localFilters[category] = {};
      }

      if (_localFilters[category]!.contains(value)) {
        _localFilters[category]!.remove(value);
      } else {
        _localFilters[category]!.add(value);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _localFilters.clear();
    });
  }

  void _applyFilters() {
    widget.onApplyFilters(_localFilters);
    Navigator.of(context).pop();
  }

  int _getTotalSelectedFilters() {
    int count = 0;
    _localFilters.forEach((_, values) {
      count += values.length;
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final totalSelected = _getTotalSelectedFilters();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      insetPadding: const EdgeInsets.all(0),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Filtros'),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Filter counts
            if (totalSelected > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Text(
                      '$totalSelected filtro${totalSelected != 1 ? 's' : ''} aplicado${totalSelected != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Limpar tudo'),
                    ),
                  ],
                ),
              ),
            // Filter sections
            Expanded(
              child: ListView(
                children: widget.filterOptions.entries.map((entry) {
                  final category = entry.key;
                  final values = entry.value;

                  return _FilterCategory(
                    title: _getCategoryLabel(category),
                    icon: _getCategoryIcon(category),
                    items: values,
                    selectedItems: _localFilters[category] ?? {},
                    onToggle: (value) => _toggleFilter(category, value),
                  );
                }).toList(),
              ),
            ),
            // Apply button
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          totalSelected > 0
                              ? 'Aplicar $totalSelected filtro${totalSelected != 1 ? 's' : ''}'
                              : 'Ver Tudo',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'authors':
        return 'Autores';
      case 'genres':
        return 'Géneros';
      case 'conditions':
        return 'Estado';
      default:
        return category;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'authors':
        return Icons.person;
      case 'genres':
        return Icons.category;
      case 'conditions':
        return Icons.info;
      default:
        return Icons.filter_list;
    }
  }
}

class _FilterCategory extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Set<String> selectedItems;
  final Function(String) onToggle;

  const _FilterCategory({
    required this.title,
    required this.icon,
    required this.items,
    required this.selectedItems,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (selectedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedItems.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Filter items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items.map((item) {
              final isSelected = selectedItems.contains(item);
              return GestureDetector(
                onTap: () => onToggle(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected ? Colors.blue : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/demo_services.dart';
import '../../core/models/backend_service_model.dart';
import '../../core/models/service_category.dart';
import '../../core/models/service_model.dart';
import '../../core/state/services_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../customer/ai_smart_match_screen.dart';
import '../customer/service_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, this.query = ''});

  final String query;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _searchCtrl;
  String _debouncedQuery = '';
  Timer? _debounce;

  // Filtering & Sorting State
  String _categoryFilter = 'all';
  String _sortOption = 'relevance'; // relevance, rating, popular, priceLow, priceHigh
  double? _maxPrice;
  double? _minRating;
  bool _onlyAvailable = false;

  final List<String> _categories = const <String>[
    'all',
    'plumbing',
    'electrical',
    'hvac',
    'carpentry',
    'painting',
    'cleaning',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.query);
    _debouncedQuery = widget.query;
    _searchCtrl.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchServices();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = _searchCtrl.text.trim();
        });
      }
    });
  }

  Future<void> _fetchServices() async {
    final provider = context.read<ServicesProvider>();
    await provider.fetchAll();
  }

  bool get _hasActiveFilters =>
      _sortOption != 'relevance' || _maxPrice != null || _minRating != null || _onlyAvailable;

  void _resetAllFilters() {
    setState(() {
      _sortOption = 'relevance';
      _maxPrice = null;
      _minRating = null;
      _onlyAvailable = false;
    });
  }

  // --- Mapping Helper Functions ---
  ServiceModel? _getDemoService(BackendService service) {
    final norm = normalizeServiceCategory(service.category);
    final demoId = norm == 'hvac' ? 'ac-maintenance' : norm;
    try {
      return kDemoServices.firstWhere((s) => s.id == demoId);
    } catch (_) {
      return null;
    }
  }

  double _getRating(BackendService service) {
    final demo = _getDemoService(service);
    if (demo == null || demo.reviews.isEmpty) return 4.8;
    final sum = demo.reviews.fold<double>(0.0, (acc, r) => acc + r.stars.toDouble());
    return double.parse((sum / demo.reviews.length).toStringAsFixed(1));
  }

  int _getReviewCount(BackendService service) {
    final norm = normalizeServiceCategory(service.category);
    return switch (norm) {
      'plumbing' => 124,
      'electrical' => 89,
      'hvac' => 95,
      'carpentry' => 78,
      'painting' => 112,
      _ => 45,
    };
  }

  String _getDuration(BackendService service) {
    final norm = normalizeServiceCategory(service.category);
    return switch (norm) {
      'plumbing' => '1–3 hrs',
      'electrical' => '1–2 hrs',
      'hvac' => '2–4 hrs',
      'carpentry' => '2–3 hrs',
      'painting' => '1–3 days',
      _ => '1–2 hrs',
    };
  }

  String _getAvailability(BackendService service) {
    final norm = normalizeServiceCategory(service.category);
    return switch (norm) {
      'plumbing' => '24/7 Available',
      'electrical' => 'Available Today',
      'hvac' => 'Same Day',
      _ => 'Available Today',
    };
  }

  String _getServiceImageUrl(BackendService service) {
    final demo = _getDemoService(service);
    if (demo != null && demo.heroImageUrl.isNotEmpty) {
      return demo.heroImageUrl;
    }
    return 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?auto=format&fit=crop&w=400&q=80';
  }

  // --- Filtering & Sorting Core Logic ---
  List<BackendService> _processServices(List<BackendService> rawList) {
    final query = _debouncedQuery.toLowerCase();
    
    // 1. Local Search Filtering
    var filtered = rawList.where((service) {
      // Query filter
      if (query.isNotEmpty) {
        final name = service.name.toLowerCase();
        final desc = service.description.toLowerCase();
        final catLabel = serviceCategoryLabel(service.category).toLowerCase();
        final rawCat = service.category.toLowerCase();
        if (!name.contains(query) && !desc.contains(query) && !catLabel.contains(query) && !rawCat.contains(query)) {
          return false;
        }
      }

      // Category chip filter
      if (_categoryFilter != 'all') {
        final normServiceCat = normalizeServiceCategory(service.category);
        if (normServiceCat != _categoryFilter) {
          return false;
        }
      }

      // Advanced filters (from Bottom Sheet)
      if (_maxPrice != null && service.basePrice > _maxPrice!) {
        return false;
      }
      if (_minRating != null && _getRating(service) < _minRating!) {
        return false;
      }
      if (_onlyAvailable) {
        final avail = _getAvailability(service).toLowerCase();
        if (!avail.contains('today') && !avail.contains('24/7') && !avail.contains('same day')) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. Sorting Logic
    switch (_sortOption) {
      case 'rating':
        filtered.sort((a, b) => _getRating(b).compareTo(_getRating(a)));
        break;
      case 'popular':
        filtered.sort((a, b) => _getReviewCount(b).compareTo(_getReviewCount(a)));
        break;
      case 'priceLow':
        filtered.sort((a, b) => a.basePrice.compareTo(b.basePrice));
        break;
      case 'priceHigh':
        filtered.sort((a, b) => b.basePrice.compareTo(a.basePrice));
        break;
      case 'relevance':
      default:
        // Keep primary order
        break;
    }

    return filtered;
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: ServioMotion.bottomSheet,
      ),
      builder: (BuildContext context) {
        final servio = context.servio;
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ServioRadius.xxl),
                ),
                boxShadow: ServioShadows.elevated,
              ),
              padding: EdgeInsets.fromLTRB(
                ServioSpacing.screenPadding,
                16,
                ServioSpacing.screenPadding,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: servio.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                    ),
                  ),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Filters & Sorting',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D23),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sort Options
                  Text(
                    'Sort By',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: servio.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _buildModalChip(
                        label: 'Relevance',
                        selected: _sortOption == 'relevance',
                        onTap: () => setModalState(() => _sortOption = 'relevance'),
                        servio: servio,
                      ),
                      _buildModalChip(
                        label: 'Highest Rated',
                        selected: _sortOption == 'rating',
                        onTap: () => setModalState(() => _sortOption = 'rating'),
                        servio: servio,
                      ),
                      _buildModalChip(
                        label: 'Most Popular',
                        selected: _sortOption == 'popular',
                        onTap: () => setModalState(() => _sortOption = 'popular'),
                        servio: servio,
                      ),
                      _buildModalChip(
                        label: 'Lowest Price',
                        selected: _sortOption == 'priceLow',
                        onTap: () => setModalState(() => _sortOption = 'priceLow'),
                        servio: servio,
                      ),
                      _buildModalChip(
                        label: 'Highest Price',
                        selected: _sortOption == 'priceHigh',
                        onTap: () => setModalState(() => _sortOption = 'priceHigh'),
                        servio: servio,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Max Price Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Maximum Price',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: servio.accent,
                        ),
                      ),
                      Text(
                        _maxPrice == null ? 'Any Price' : '${_maxPrice!.toStringAsFixed(0)} EGP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D23),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maxPrice ?? 3000,
                    min: 200,
                    max: 3000,
                    divisions: 14,
                    activeColor: const Color(0xFF1A1D23),
                    inactiveColor: servio.border,
                    label: _maxPrice == null ? 'Any Price' : '${_maxPrice!.toStringAsFixed(0)} EGP',
                    onChanged: (val) {
                      setModalState(() {
                        _maxPrice = val == 3000 ? null : val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Minimum Rating
                  Text(
                    'Minimum Rating',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: servio.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _buildModalChip(
                        label: 'Any Rating',
                        selected: _minRating == null,
                        onTap: () => setModalState(() => _minRating = null),
                        servio: servio,
                      ),
                      const SizedBox(width: 8),
                      _buildModalChip(
                        label: '4.5+ ★',
                        selected: _minRating == 4.5,
                        onTap: () => setModalState(() => _minRating = 4.5),
                        servio: servio,
                      ),
                      const SizedBox(width: 8),
                      _buildModalChip(
                        label: '4.8+ ★',
                        selected: _minRating == 4.8,
                        onTap: () => setModalState(() => _minRating = 4.8),
                        servio: servio,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Availability Switch
                  SwitchListTile(
                    title: Text(
                      'Available Today / Same Day Only',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D23),
                      ),
                    ),
                    value: _onlyAvailable,
                    activeColor: const Color(0xFF1A1D23),
                    onChanged: (val) {
                      setModalState(() {
                        _onlyAvailable = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _resetAllFilters();
                            });
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: servio.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ServioRadius.md),
                            ),
                          ),
                          child: Text(
                            'Reset All',
                            style: TextStyle(color: servio.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ServioPrimaryButton(
                          label: 'Apply Filters',
                          onPressed: () {
                            setState(() {}); // Apply state change locally
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ServioThemeExtension servio,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1D23) : servio.surfaceAlt,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(
            color: selected ? const Color(0xFF1A1D23) : servio.border.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF262B34),
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final provider = context.watch<ServicesProvider>();
    final rawServices = provider.services;
    final filteredServices = _processServices(rawServices);

    return Scaffold(
      backgroundColor: ServioColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'SERVIO',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1A1D23),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: _hasActiveFilters ? const Color(0xFF9A8C73) : const Color(0xFF1A1D23),
              ),
              tooltip: 'Filters & Sorting',
              onPressed: _showFilterSheet,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Sticky Search Header Area
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              8,
              ServioSpacing.screenPadding,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Search',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 28,
                    color: const Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 12),
                
                SearchBar(
                  controller: _searchCtrl,
                  elevation: const WidgetStatePropertyAll<double>(0),
                  backgroundColor: const WidgetStatePropertyAll<Color>(
                    ServioColors.backgroundSoftLight,
                  ),
                  shape: WidgetStatePropertyAll<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: servio.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 56, maxHeight: 56),
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                  leading: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF6B6560),
                    size: 24,
                  ),
                  hintText: 'Services & keywords',
                  hintStyle: const WidgetStatePropertyAll<TextStyle>(
                    TextStyle(
                      color: Color(0xFF6B6560),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  textStyle: const WidgetStatePropertyAll<TextStyle>(
                    TextStyle(
                      color: Color(0xFF262B34),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  trailing: <Widget>[
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF1A1D23),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _debouncedQuery = '';
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horizontal Category Chips Row
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final catKey = _categories[index];
                      final active = _categoryFilter == catKey;
                      final label = catKey == 'all' ? 'All Results' : serviceCategoryLabel(catKey);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _categoryFilter = catKey;
                            });
                          },
                          child: AnimatedContainer(
                            duration: ServioMotion.micro,
                            curve: ServioMotion.curve,
                            height: 44,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF1A1D23) : const Color(0xFFe4e2df),
                              borderRadius: BorderRadius.circular(ServioRadius.full),
                              border: Border.all(
                                color: active ? const Color(0xFF1A1D23) : const Color(0xFFc6c6cb).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: active ? Colors.white : const Color(0xFF262B34),
                                fontSize: 13,
                                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Header for Results Section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              12,
              ServioSpacing.screenPadding,
              8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(
                      Icons.handyman_rounded,
                      color: Color(0xFF9A8C73),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Services',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${filteredServices.length} result${filteredServices.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF6B6560),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Results List & Status States
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF9A8C73),
              backgroundColor: Colors.white,
              onRefresh: _fetchServices,
              child: _buildMainContent(context, provider, filteredServices),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ServicesProvider provider, List<BackendService> results) {
    if (provider.loading && provider.services.isEmpty) {
      return const _SkeletonLoader();
    }

    if (provider.error != null && provider.services.isEmpty) {
      return _buildErrorState(provider.error!);
    }

    if (results.isEmpty) {
      return _EmptyState(
        hasActiveFilters: _hasActiveFilters,
        searchQuery: _debouncedQuery,
        onResetFilters: () {
          setState(() {
            _resetAllFilters();
          });
        },
        onClearSearch: () {
          setState(() {
            _searchCtrl.clear();
            _debouncedQuery = '';
          });
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        ServioSpacing.screenPadding,
        8,
        ServioSpacing.screenPadding,
        ServioSpacing.screenPadding + 24,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: results.length + (provider.loading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == results.length) {
          // Bottom loading shimmer indicator for infinite scrolls
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xFF9A8C73),
                ),
              ),
            ),
          );
        }
        return _buildServiceCard(context, results[index]);
      },
    );
  }

  Widget _buildServiceCard(BuildContext context, BackendService service) {
    final rating = _getRating(service);
    final reviews = _getReviewCount(service);
    final duration = _getDuration(service);
    final availability = _getAvailability(service);
    final imageUrl = _getServiceImageUrl(service);
    final categoryLabel = serviceCategoryLabel(service.category);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ServiceDetailScreen(serviceId: service.id),
          ),
        );
      },
      child: AnimatedContainer(
        duration: ServioMotion.normal,
        padding: const EdgeInsets.all(ServioSpacing.cardPadding),
        decoration: BoxDecoration(
          color: const Color(0xFFF3EDE7), // bg-surface-warm matching Stitch
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF9A8C73).withValues(alpha: 0.18), // border-taupe-accent/20 matching Stitch
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image Left Section - Highly Prominent (96x96)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 96,
                height: 96,
                color: const Color(0xFFe4e2df),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Color(0xFF9A8C73),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Color(0xFF6B6560),
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content Center Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Category Caps Subtitle for visual hierarchy
                  Text(
                    categoryLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A8C73), // taupe-accent
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Service Title
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D23), // text-navy-anchor
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Description
                  Text(
                    service.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6560), // text-muted
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Premium Visual M3 Chips Wrap
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      // Price Range Chip - Soft Green Accent
                      _buildTagBadge(
                        label: 'From ${service.basePrice.toStringAsFixed(0)} EGP',
                        backgroundColor: const Color(0xFFE8F8F0),
                        textColor: const Color(0xFF1B8A5A),
                        icon: Icons.payments_outlined,
                      ),
                      // Rating Chip - Gold Accent
                      _buildTagBadge(
                        label: '$rating ($reviews)',
                        backgroundColor: const Color(0xFFFCF5E3),
                        textColor: const Color(0xFFB58900),
                        icon: Icons.star_rounded,
                      ),
                      // Duration Chip - Muted Dark Gray
                      _buildTagBadge(
                        label: duration,
                        backgroundColor: const Color(0xFFEAE8E5),
                        textColor: const Color(0xFF45474B),
                        icon: Icons.schedule_rounded,
                      ),
                      // Availability Chip - Light Blue/Green Accent
                      _buildTagBadge(
                        label: availability,
                        backgroundColor: const Color(0xFFE8FAF4),
                        textColor: const Color(0xFF1B8A7A),
                        icon: Icons.event_available_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // High-Affordance Action Chevron (White Circular Elevated)
            Padding(
              padding: const EdgeInsets.only(top: 32), // Vertically centered roughly with image
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF9A8C73).withValues(alpha: 0.15),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9A8C73),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 11,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFba1a1a).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Color(0xFFba1a1a),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gateway Connection Timeout',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D23),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A network failure or API timeout occurred while connecting to the services repository. Details: $errorText',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6560),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: ServioPrimaryButton(
                label: 'Retry Connection',
                onPressed: _fetchServices,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Elite Shimmer Skeleton Loader ---
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.35 + (_controller.value * 0.45),
          child: child,
        );
      },
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: ServioSpacing.screenPadding, vertical: 8),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EDE7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF9A8C73).withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Image Placeholder Skeleton
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFe4e2df),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              // Content Placeholder Skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe4e2df),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe4e2df),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe4e2df),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe4e2df),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 54,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFe4e2df),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Elite Illustrative Empty State ---
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasActiveFilters,
    required this.searchQuery,
    required this.onResetFilters,
    required this.onClearSearch,
  });

  final bool hasActiveFilters;
  final String searchQuery;
  final VoidCallback onResetFilters;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            padding: const EdgeInsets.all(ServioSpacing.screenPadding),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: ServioGradients.warm,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF9A8C73).withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    size: 52,
                    color: Color(0xFF9A8C73),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No matching services found',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We couldn\'t find any services matching your search or filters. Try adjusting your settings below, clearing search tags, or using AI Smart Match.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6560),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Clear Search/Filters Actions Group
                if (hasActiveFilters || searchQuery.isNotEmpty) ...<Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.search_off_rounded, size: 16),
                            label: const Text('Clear Query'),
                            onPressed: onClearSearch,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF262B34),
                              side: const BorderSide(color: Color(0xFFDDD5CC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (hasActiveFilters)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                            label: const Text('Reset Filters'),
                            onPressed: onResetFilters,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF262B34),
                              side: const BorderSide(color: Color(0xFFDDD5CC)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: 220,
                  height: 48,
                  child: ServioPrimaryButton(
                    label: 'Try Smart Match',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiSmartMatchScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

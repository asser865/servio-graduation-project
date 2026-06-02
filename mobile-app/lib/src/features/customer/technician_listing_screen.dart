import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_worker_model.dart';
import '../../core/models/service_category.dart';
import '../../core/services/location_service.dart';
import '../../core/state/customer_addresses_state.dart';
import '../../core/state/workers_state.dart';
import 'technician_profile_screen.dart';

class TechnicianListingScreen extends StatefulWidget {
  const TechnicianListingScreen({
    this.serviceId,
    this.category,
    this.title,
    super.key,
  });

  final String? serviceId;
  final String? category;
  final String? title;

  @override
  State<TechnicianListingScreen> createState() =>
      _TechnicianListingScreenState();
}

class _TechnicianListingScreenState extends State<TechnicianListingScreen> {
  bool _verifiedOnly = false;

  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};
  LatLng? _customerLatLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveCustomerLocation();
      final serviceId =
          _looksLikeMongoId(widget.serviceId) ? widget.serviceId : null;
      final category = normalizeServiceCategory(
        widget.category ??
            (_looksLikeMongoId(widget.serviceId) ? null : widget.serviceId),
      );
      context.read<WorkersProvider>().fetchAll(
            serviceId: serviceId,
            category: category.isEmpty ? null : category,
          );
    });
  }

  void _resolveCustomerLocation() {
    CustomerAddressesProvider addressesProvider;
    try {
      addressesProvider = context.read<CustomerAddressesProvider>();
    } catch (_) {
      return;
    }
    _pickCustomerLatLng(addressesProvider);
    if (addressesProvider.addresses.isEmpty && !addressesProvider.loading) {
      addressesProvider.load().then((_) {
        if (!mounted) return;
        _pickCustomerLatLng(addressesProvider);
      });
    }
  }

  void _pickCustomerLatLng(CustomerAddressesProvider provider) {
    for (final addr in provider.addresses) {
      if (addr.lat != null && addr.lng != null) {
        if (mounted) {
          setState(() {
            _customerLatLng = LatLng(addr.lat!, addr.lng!);
          });
          _geocodePendingWorkers(context.read<WorkersProvider>().workers);
        }
        return;
      }
    }
  }

  void _geocodePendingWorkers(List<BackendWorker> workers) {
    if (_customerLatLng == null) return;
    final uniqueLabels = workers
        .map((w) => w.locationLabel)
        .where((label) => label.trim().isNotEmpty)
        .toSet();
    for (final label in uniqueLabels) {
      if (!_geocodeCache.containsKey(label)) {
        _geocodeLabel(label);
      }
    }
  }

  Future<void> _geocodeLabel(String label) async {
    final latLng = await LocationService().geocodeAddress(label);
    if (!mounted) return;
    setState(() {
      _geocodeCache[label] = latLng;
    });
  }

  String? _distanceLabelFor(BackendWorker worker) {
    final customerPos = _customerLatLng;
    if (customerPos == null) return null;
    final label = worker.locationLabel.trim();
    if (label.isEmpty) return null;
    if (!_geocodeCache.containsKey(label)) {
      _geocodeLabel(label);
      return null;
    }
    final workerPos = _geocodeCache[label];
    if (workerPos == null) return null;
    final km =
        const Distance().as(LengthUnit.Kilometer, customerPos, workerPos);
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkersProvider>();
    final serviceId =
        _looksLikeMongoId(widget.serviceId) ? widget.serviceId!.trim() : '';
    final category = normalizeServiceCategory(
      widget.category ??
          (_looksLikeMongoId(widget.serviceId) ? null : widget.serviceId),
    );
    var workers = _filterWorkersForSelection(
      provider.workers,
      serviceId: serviceId,
      category: category,
    );
    if (_verifiedOnly) {
      workers = workers.where((w) => w.isVerified).toList();
    }

    if (!provider.loading && workers.isNotEmpty) {
      _geocodePendingWorkers(workers);
    }

    final listingTitle = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : category.isNotEmpty
            ? serviceCategoryLabel(category)
            : 'Technicians';
    final selectedServiceName = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : category.isNotEmpty
            ? listingTitle
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            ),
          ),
          // Context header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.handyman_rounded,
                        color: Color(0xFF9A8C73),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        listingTitle,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Color(0xFF1A1D23),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Showing available professionals near you.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6560),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Filter bar
          SliverToBoxAdapter(
            child: _FilterBar(
              verifiedOnly: _verifiedOnly,
              onVerifiedToggle: () =>
                  setState(() => _verifiedOnly = !_verifiedOnly),
            ),
          ),
          // Content
          if (provider.loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9A8C73),
                ),
              ),
            )
          else if (provider.error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Color(0xFF6B6560)),
                ),
              ),
            )
          else if (workers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _TechnicianEmptyState(
                hasFilter: _verifiedOnly,
                onClearFilters: () => setState(() => _verifiedOnly = false),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final worker = workers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TechnicianCard(
                        worker: worker,
                        distanceLabel: _distanceLabelFor(worker),
                        onViewProfile: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TechnicianProfileScreen(
                                technicianId: worker.id,
                                selectedServiceId:
                                    serviceId.isNotEmpty ? serviceId : null,
                                selectedServiceCategory:
                                    category.isNotEmpty ? category : null,
                                selectedServiceName: selectedServiceName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: workers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBF9F6).withValues(alpha: 0.85),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF1A1D23).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: <Widget>[
                  // Back button
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: const Color(0xFF1A1D23),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  // Title
                  const Expanded(
                    child: Text(
                      'Technicians',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Color(0xFF1A1D23),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Trailing placeholder to balance layout
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _looksLikeMongoId(String? value) =>
    value != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);

List<BackendWorker> _filterWorkersForSelection(
  List<BackendWorker> workers, {
  required String serviceId,
  required String category,
}) {
  if (serviceId.isEmpty && category.isEmpty) return workers;
  return workers.where((worker) {
    final serviceMatches =
        serviceId.isNotEmpty && worker.offersService(serviceId);
    final categoryMatches =
        category.isNotEmpty && worker.offersCategory(category);
    return serviceMatches || categoryMatches;
  }).toList();
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.verifiedOnly,
    required this.onVerifiedToggle,
  });

  final bool verifiedOnly;
  final VoidCallback onVerifiedToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: <Widget>[
          // Filters button
          _FilterChip(
            label: 'Filters',
            icon: Icons.tune_rounded,
            active: false,
            onTap: () {},
          ),
          const SizedBox(width: 10),
          // Verified Only toggle
          _FilterChip(
            label: 'Verified Only',
            icon: Icons.verified_rounded,
            active: verifiedOnly,
            onTap: onVerifiedToggle,
          ),
          const SizedBox(width: 10),
          // Distance (placeholder)
          _FilterChip(
            label: 'Distance',
            trailingIcon: Icons.expand_more_rounded,
            active: false,
            onTap: () {},
          ),
          const SizedBox(width: 10),
          // Rating (placeholder)
          _FilterChip(
            label: 'Rating',
            trailingIcon: Icons.expand_more_rounded,
            active: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.active = false,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF1A1D23) : const Color(0xFFF3EDE7);
    final fg = active ? Colors.white : const Color(0xFF1A1D23);
    final borderColor = active
        ? const Color(0xFF1A1D23)
        : const Color(0xFF9A8C73).withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF1A1D23).withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
                letterSpacing: 0.1,
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Technician card (Stitch redesign)
// ---------------------------------------------------------------------------

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({
    required this.worker,
    required this.onViewProfile,
    this.distanceLabel,
  });

  final BackendWorker worker;
  final VoidCallback onViewProfile;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9A8C73).withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // Decorative gradient corner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: <Color>[
                    const Color(0xFF9A8C73).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(80),
                ),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Avatar row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Avatar + verified badge
                    _WorkerAvatar(worker: worker),
                    const SizedBox(width: 16),
                    // Name / specialty / distance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  worker.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18,
                                    color: Color(0xFF1A1D23),
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Rating badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3EDE7),
                                  borderRadius: BorderRadius.circular(9999),
                                  border: Border.all(
                                    color: const Color(0xFF9A8C73)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: Color(0xFF9A8C73),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      worker.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1D23),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Specialty
                          Text(
                            worker.skills.isNotEmpty
                                ? worker.skills.first
                                : 'General Services',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B6560),
                            ),
                          ),
                          // Distance
                          if (distanceLabel != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Color(0xFF6B6560),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  distanceLabel!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6B6560),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Skills chips
                if (worker.skills.length > 1) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: worker.skills
                        .skip(1)
                        .take(3)
                        .map(
                          (skill) => Container(
                            height: 28,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9A8C73)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1D23),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                // Action row
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFF9A8C73).withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      // View Profile button
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: onViewProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1D23),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'View Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Bookmark button
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(
                              color: const Color(0xFF9A8C73)
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.bookmark_outline_rounded,
                            size: 20,
                            color: Color(0xFF1A1D23),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.worker});

  final BackendWorker worker;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF9A8C73).withValues(alpha: 0.18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: worker.profileImage.isEmpty
              ? _Initials(initials: worker.initials)
              : Image.network(
                  worker.profileImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _Initials(initials: worker.initials),
                ),
        ),
        if (worker.isVerified)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDE7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 12,
                color: Color(0xFF1A1D23),
              ),
            ),
          ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Color(0xFF1A1D23),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _TechnicianEmptyState extends StatelessWidget {
  const _TechnicianEmptyState({
    required this.hasFilter,
    required this.onClearFilters,
  });

  final bool hasFilter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF9A8C73).withValues(alpha: 0.1),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: Color(0xFF9A8C73),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No technicians found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: Color(0xFF1A1D23),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or expanding your search radius to find available professionals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6560),
                height: 1.5,
              ),
            ),
            if (hasFilter) ...<Widget>[
              const SizedBox(height: 24),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onClearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1D23),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

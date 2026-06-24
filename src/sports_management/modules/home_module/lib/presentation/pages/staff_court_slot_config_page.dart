import 'package:facility_module/facility_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';

import '../cubit/staff_court_listing/staff_court_listing_cubit.dart';
import '../cubit/staff_court_listing/staff_court_listing_state.dart';

class StaffCourtSlotConfigPage extends StatefulWidget {
  const StaffCourtSlotConfigPage({super.key});

  @override
  State<StaffCourtSlotConfigPage> createState() =>
      _StaffCourtSlotConfigPageState();
}

class _StaffCourtSlotConfigPageState extends State<StaffCourtSlotConfigPage> {
  static const _primaryColor = Color(0xFFFF5600);

  late final StaffCourtListingCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedSportIds = <String>{};
  List<SportEntity> _sports = const [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cubit = StaffCourtListingCubit(GetIt.I(), GetIt.I(), GetIt.I());
    _cubit.loadFacilitiesAndCourts();
    _loadSports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _loadSports() async {
    try {
      final response = await GetIt.I<GetSportsUseCase>()();
      if (!mounted || !response.success || response.data == null) return;
      setState(() => _sports = response.data!);
    } catch (_) {
      // Court cards still work when sport metadata cannot be loaded.
    }
  }

  String _sportName(String? sportId) {
    for (final sport in _sports) {
      if (sport.id == sportId) {
        return sport.name ?? 'Môn thể thao';
      }
    }
    return 'Môn thể thao';
  }

  List<CourtEntity> _filteredCourts(List<CourtEntity> courts) {
    final query = _searchQuery.trim().toLowerCase();
    return courts.where((court) {
      final matchesSearch =
          query.isEmpty || (court.name ?? '').toLowerCase().contains(query);
      return matchesSearch;
    }).toList()..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vận hành khung giờ sân',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Chọn sân để cấu hình khung giờ hoạt động',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên sân',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildCourtTile(CourtEntity court, ThemeData theme) {
    final isActive = court.status == 'ACTIVE';
    final sportName = _sportName(court.sportId);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  court.name ?? 'Sân đấu',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Hoạt động' : 'Tạm dừng',
                      style: TextStyle(
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              context.push(
                '/staff/court-slot-config/${court.id}',
                extra: {
                  'courtName': court.name,
                  'sportName': sportName,
                  'courtStatus': court.status,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text(
              'Cấu hình',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportGroup({
    required String sportId,
    required String sportName,
    required List<CourtEntity> courts,
    required ThemeData theme,
  }) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final isExpanded = isSearching || _expandedSportIds.contains(sportId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(
            'staff-slot-config-sport-$sportId-$isSearching',
          ),
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_tennis_rounded,
              color: _primaryColor,
            ),
          ),
          title: Text(
            sportName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${courts.length} sân',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          onExpansionChanged: (expanded) {
            if (isSearching) return;
            setState(() {
              if (expanded) {
                _expandedSportIds.add(sportId);
              } else {
                _expandedSportIds.remove(sportId);
              }
            });
          },
          children: courts
              .map((court) => _buildCourtTile(court, theme))
              .toList(),
        ),
      ),
    );
  }

  List<({String id, String name, List<CourtEntity> courts})> _groupCourts(
    List<CourtEntity> courts,
  ) {
    final grouped = <String, List<CourtEntity>>{};
    for (final court in courts) {
      final sportId = court.sportId ?? 'unknown';
      grouped.putIfAbsent(sportId, () => <CourtEntity>[]).add(court);
    }

    final groups = grouped.entries
        .map(
          (entry) => (
            id: entry.key,
            name: _sportName(entry.key == 'unknown' ? null : entry.key),
            courts: entry.value,
          ),
        )
        .toList();
    groups.sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vận hành khung giờ sân')),
      body: BlocBuilder<StaffCourtListingCubit, StaffCourtListingState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state is StaffCourtListingLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (state is StaffCourtListingError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _cubit.loadFacilitiesAndCourts,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is StaffCourtListingLoaded) {
            if (state.facilities.isEmpty || state.courts.isEmpty) {
              return _buildEmptyState(
                icon: Icons.sports_tennis_rounded,
                message: 'Chưa có sân nào để cấu hình',
              );
            }

            final courts = _filteredCourts(state.courts);
            final groups = _groupCourts(courts);
            return RefreshIndicator(
              onRefresh: _cubit.loadFacilitiesAndCourts,
              color: _primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    sliver: SliverToBoxAdapter(child: _buildHeader(theme)),
                  ),
                  if (courts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(
                        icon: Icons.search_off_rounded,
                        message: 'Không tìm thấy sân phù hợp',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _buildSportGroup(
                            sportId: group.id,
                            sportName: group.name,
                            courts: group.courts,
                            theme: theme,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

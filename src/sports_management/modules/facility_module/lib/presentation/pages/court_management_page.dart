import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../../facility_module.dart';
import '../cubit/court/court_management_cubit.dart';
import '../cubit/court/court_management_state.dart';
import '../widgets/crud_popup.dart';

class CourtManagementPage extends StatefulWidget {
  final String facilityId;
  final String? facilityName;
  final bool isEmbedded;

  const CourtManagementPage({
    super.key,
    required this.facilityId,
    this.facilityName,
    this.isEmbedded = false,
  });

  @override
  State<CourtManagementPage> createState() => _CourtManagementPageState();
}

class _CourtManagementPageState extends State<CourtManagementPage> {
  late CourtManagementCubit _cubit;
  List<SportEntity> _sportList = [];
  final Set<String> _expandedSportIds = <String>{};
  bool _isLoadingSports = false;
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = CourtManagementCubit(GetIt.I(), GetIt.I(), GetIt.I(), GetIt.I());
    _cubit.loadCourts(widget.facilityId);
    _loadSports();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _loadSports() async {
    if (!mounted) return;
    setState(() => _isLoadingSports = true);
    try {
      final useCase = GetIt.I<GetSportsUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _sportList = response.data!;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingSports = false);
  }

  String _formatPrice(int price) {
    final s = price.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return '${result.toString()} đ';
  }

  Future<void> _showFormDialog({CourtEntity? court}) async {
    final isEdit = court != null;
    final nameController = TextEditingController(text: court?.name);
    final priceController = TextEditingController(
      text: court != null
          ? (((court as dynamic).pricePerHour ?? 0) as num).toString()
          : '',
    );
    VoidCallback? submitAfterSheetClosed;

    String? selectedSportId = court?.sportId;
    String selectedStatus = court?.status ?? 'ACTIVE';

    await CrudPopup.showForm<void>(
      context,
      title: isEdit ? 'Chỉnh sửa sân đấu' : 'Thêm sân mới',
      submitLabel: isEdit ? 'Lưu thay đổi' : 'Thêm mới',
      icon: isEdit ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
      barrierDismissible: false,
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên sân',
              hintText: 'Ví dụ: Sân 1, Sân A...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Đơn giá/giờ (đ)',
              hintText: 'Ví dụ: 200000...',
            ),
          ),
          const SizedBox(height: 12),

          // Sport Dropdown (chỉ hiển thị khi Thêm mới, Sửa thì khóa hoặc ẩn)
          if (!isEdit) ...[
            _isLoadingSports
                ? const CircularProgressIndicator(color: _primaryColor)
                : DropdownButtonFormField<String>(
                    initialValue: selectedSportId,
                    decoration: const InputDecoration(
                      labelText: 'Môn thể thao',
                    ),
                    items: _sportList
                        .map(
                          (sport) => DropdownMenuItem(
                            value: sport.id,
                            child: Text(sport.name ?? 'Môn thể thao'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedSportId = val;
                      });
                    },
                  ),
            const SizedBox(height: 16),
          ],

          DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: const InputDecoration(labelText: 'Trạng thái sân'),
            items: const [
              DropdownMenuItem(value: 'ACTIVE', child: Text('Hoạt động')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('Tạm ngưng')),
              DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setDialogState(() {
                selectedStatus = value;
              });
            },
          ),
        ],
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        final priceText = priceController.text.trim();

        if (name.isEmpty || priceText.isEmpty) {
          CrudPopup.showMessage(
            context,
            message: 'Vui lòng điền đầy đủ thông tin',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        final price = int.tryParse(priceText);
        if (price == null || price <= 0) {
          CrudPopup.showMessage(
            context,
            message: 'Đơn giá không hợp lệ',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        if (!isEdit && selectedSportId == null) {
          CrudPopup.showMessage(
            context,
            message: 'Vui lòng chọn môn thể thao',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        final status = selectedStatus;

        if (isEdit) {
          submitAfterSheetClosed = () => _cubit.updateCourt(
            facilityId: widget.facilityId,
            id: court.id,
            name: name,
            pricePerHour: price,
            status: status,
          );
        } else {
          submitAfterSheetClosed = () => _cubit.createCourt(
            facilityId: widget.facilityId,
            sportId: selectedSportId!,
            name: name,
            pricePerHour: price,
            status: status,
          );
        }
        FocusManager.instance.primaryFocus?.unfocus();
        final navigator = Navigator.of(context);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        navigator.pop();
      },
    ).whenComplete(() async {
      final submit = submitAfterSheetClosed;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      nameController.dispose();
      priceController.dispose();
      if (submit != null && mounted) {
        submit();
      }
    });
  }

  Future<void> _confirmDelete(CourtEntity court) async {
    final confirmed = await CrudPopup.confirmDelete(
      context,
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc chắn muốn xóa sân "${court.name}" không?',
      cancelLabel: 'Hủy',
      confirmLabel: 'Xóa',
    );
    if (confirmed) {
      _cubit.deleteCourt(widget.facilityId, court.id);
    }
  }

  SportEntity _sportForCourt(CourtEntity court) {
    return _sportList.firstWhere(
      (s) => s.id == court.sportId,
      orElse: () => SportEntity(id: court.sportId ?? '', name: 'Môn thể thao'),
    );
  }

  Widget _buildCourtTile(CourtEntity court, ThemeData theme) {
    final isActive = court.status == 'ACTIVE';
    final isMaintenance = court.status == 'MAINTENANCE';
    final statusColor = isActive
        ? Colors.green
        : isMaintenance
        ? Colors.orange
        : Colors.grey;
    final statusLabel = isActive
        ? 'Sẵn sàng hoạt động'
        : isMaintenance
        ? 'Đang bảo trì'
        : 'Tạm ngưng';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  court.name ?? 'Sân đấu',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Giá: ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatPrice(
                        ((court as dynamic).pricePerHour ?? 0) as int,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      '/giờ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
                onPressed: () => _showFormDialog(court: court),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(court),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSportGroup({
    required SportEntity sport,
    required List<CourtEntity> courts,
    required ThemeData theme,
  }) {
    final sportId = sport.id;
    final isExpanded = _expandedSportIds.contains(sportId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('court-sport-$sportId'),
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(
            Icons.sports_tennis_rounded,
            color: _primaryColor,
          ),
          title: Text(
            sport.name ?? 'Môn thể thao',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          subtitle: Text(
            '${courts.length} sân',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          onExpansionChanged: (expanded) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facilityName = widget.facilityName ?? 'Cơ sở';

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: Text(
                facilityName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: _primaryColor,
                    size: 28,
                  ),
                  onPressed: () => _showFormDialog(),
                ),
                const SizedBox(width: 8),
              ],
            ),
      floatingActionButton: widget.isEmbedded
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              backgroundColor: _primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: BlocConsumer<CourtManagementCubit, CourtManagementState>(
        bloc: _cubit,
        listener: (context, state) {
          if (state is CourtManagementSuccess) {
            CrudPopup.showMessage(
              context,
              message: state.message,
              tone: CrudPopupTone.success,
            );
          }
          if (state is CourtManagementError) {
            CrudPopup.showMessage(
              context,
              message: state.message,
              tone: CrudPopupTone.danger,
            );
          }
        },
        builder: (context, state) {
          if (state is CourtManagementLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (state is CourtManagementError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _cubit.loadCourts(widget.facilityId),
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            );
          }

          if (state is CourtManagementLoaded) {
            final courts = state.courts;

            if (courts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cơ sở này chưa cấu hình sân đấu',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            final groupedCourts = <String, List<CourtEntity>>{};
            final sportsById = <String, SportEntity>{};

            for (final court in courts) {
              final sport = _sportForCourt(court);
              final sportId = sport.id;
              sportsById[sportId] = sport;
              groupedCourts
                  .putIfAbsent(sportId, () => <CourtEntity>[])
                  .add(court);
            }

            final sportIds = groupedCourts.keys.toList()
              ..sort((a, b) {
                final sportA = sportsById[a]?.name ?? '';
                final sportB = sportsById[b]?.name ?? '';
                return sportA.compareTo(sportB);
              });

            return RefreshIndicator(
              onRefresh: () => _cubit.loadCourts(widget.facilityId),
              color: _primaryColor,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sportIds.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sportId = sportIds[index];
                  final sport =
                      sportsById[sportId] ??
                      SportEntity(id: sportId, name: 'Môn thể thao');
                  final sportCourts = groupedCourts[sportId]!
                    ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

                  return _buildSportGroup(
                    sport: sport,
                    courts: sportCourts,
                    theme: theme,
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';
import '../../domain/usecases/get_staff_users_usecase.dart';
import '../cubit/facility/facility_management_cubit.dart';
import '../cubit/facility/facility_management_state.dart';
import '../widgets/crud_popup.dart';

class FacilityManagementPage extends StatefulWidget {
  final Function(FacilityEntity)? onFacilityTap;
  final bool isEmbedded;

  const FacilityManagementPage({
    super.key,
    this.onFacilityTap,
    this.isEmbedded = false,
  });

  @override
  State<FacilityManagementPage> createState() => _FacilityManagementPageState();
}

class _FacilityManagementPageState extends State<FacilityManagementPage> {
  late FacilityManagementCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  List<FacilityEntity> _allFacilities = [];
  List<FacilityEntity> _filteredFacilities = [];
  List<UserEntity> _staffList = [];
  bool _isLoadingStaff = false;
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = FacilityManagementCubit(
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
    );
    _cubit.loadFacilities();
    _loadStaff();
  }

  @override
  void dispose() {
    _cubit.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    if (!mounted) return;
    setState(() => _isLoadingStaff = true);
    try {
      final useCase = GetIt.I<GetStaffUsersUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _staffList = response.data!;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingStaff = false);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredFacilities = _allFacilities
          .where(
            (f) =>
                (f.name ?? '').toLowerCase().contains(query.toLowerCase()) ||
                (f.address ?? '').toLowerCase().contains(query.toLowerCase()) ||
                (f.description ?? '').toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
          .toList();
    });
  }

  bool _isValidObjectId(String? value) {
    if (value == null) return false;
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value.trim());
  }

  Future<void> _showFormDialog({FacilityEntity? facility}) async {
    final isEdit = facility != null;
    final nameController = TextEditingController(text: facility?.name);
    final addressController = TextEditingController(text: facility?.address);
    VoidCallback? submitAfterSheetClosed;
    final cityController = TextEditingController(
      text: facility?.description ?? 'Hà Nội',
    );

    // Tìm staffId hiện tại nếu có
    String? selectedStaffId = facility?.ownerId;
    bool active = facility == null || facility.status == 'ACTIVE';

    await CrudPopup.showForm<void>(
      context,
      title: isEdit ? 'Chỉnh sửa cơ sở' : 'Thêm cơ sở mới',
      submitLabel: isEdit ? 'Lưu thay đổi' : 'Thêm mới',
      icon: isEdit
          ? Icons.edit_location_alt_outlined
          : Icons.add_business_rounded,
      barrierDismissible: false,
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên cơ sở',
              hintText: 'Nhập tên cơ sở...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ',
              hintText: 'Nhập địa chỉ đầy đủ...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'Thành phố',
              hintText: 'Nhập thành phố...',
            ),
          ),
          const SizedBox(height: 12),

          // Staff Dropdown
          _isLoadingStaff
              ? const CircularProgressIndicator(color: _primaryColor)
              : DropdownButtonFormField<String>(
                  initialValue: _staffList.any((s) => s.id == selectedStaffId)
                      ? selectedStaffId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Nhân viên phụ trách',
                  ),
                  items: _staffList
                      .map(
                        (staff) => DropdownMenuItem(
                          value: staff.id,
                          child: Text(staff.name ?? staff.email ?? 'Staff'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedStaffId = val;
                    });
                  },
                ),
          const SizedBox(height: 16),

          // Active Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trạng thái hoạt động',
                style: TextStyle(fontSize: 14),
              ),
              Switch(
                value: active,
                activeThumbColor: _primaryColor,
                onChanged: (val) {
                  setDialogState(() {
                    active = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      onSubmit: () async {
        final name = nameController.text.trim();
        final address = addressController.text.trim();
        final city = cityController.text.trim();
        if (name.isEmpty || address.isEmpty || city.isEmpty) {
          CrudPopup.showMessage(
            context,
            message: 'Vui lòng điền đầy đủ thông tin',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        final staffIds = _isValidObjectId(selectedStaffId)
            ? [selectedStaffId!.trim()]
            : <String>[];

        if (isEdit) {
          submitAfterSheetClosed = () => _cubit.updateFacility(
            id: facility.id,
            name: name,
            address: address,
            city: city,
            staffIds: staffIds,
            active: active,
          );
        } else {
          submitAfterSheetClosed = () => _cubit.createFacility(
            name: name,
            address: address,
            city: city,
            staffIds: staffIds,
            active: active,
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
      addressController.dispose();
      cityController.dispose();
      if (submit != null && mounted) {
        submit();
      }
    });
  }

  Future<void> _confirmDelete(FacilityEntity facility) async {
    final confirmed = await CrudPopup.confirmDelete(
      context,
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc chắn muốn xóa cơ sở "${facility.name}" không?',
      cancelLabel: 'Hủy',
      confirmLabel: 'Xóa',
    );
    if (confirmed) {
      _cubit.deleteFacility(facility.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text(
                'QUẢN LÝ CƠ SỞ',
                style: TextStyle(
                  fontSize: 14,
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
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm cơ sở, địa chỉ...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Facilities List
          Expanded(
            child: BlocConsumer<FacilityManagementCubit, FacilityManagementState>(
              bloc: _cubit,
              listener: (context, state) {
                if (state is FacilityManagementSuccess) {
                  CrudPopup.showMessage(
                    context,
                    message: state.message,
                    tone: CrudPopupTone.success,
                  );
                }
                if (state is FacilityManagementError) {
                  CrudPopup.showMessage(
                    context,
                    message: state.message,
                    tone: CrudPopupTone.danger,
                  );
                }
              },
              builder: (context, state) {
                if (state is FacilityManagementLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                if (state is FacilityManagementLoaded) {
                  _allFacilities = state.facilities;
                  if (_searchController.text.isEmpty) {
                    _filteredFacilities = _allFacilities;
                  }
                }

                if (_filteredFacilities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không tìm thấy cơ sở nào',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _cubit.loadFacilities(),
                  color: _primaryColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 24,
                    ),
                    itemCount: _filteredFacilities.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final facility = _filteredFacilities[index];
                      final isActive = facility.status == 'ACTIVE';

                      // Tìm tên nhân viên phụ trách nếu trùng khớp
                      final staffUser = _staffList.firstWhere(
                        (s) => s.id == facility.ownerId,
                        orElse: () => UserEntity(
                          id: '',
                          name:
                              facility.ownerId != null &&
                                  facility.ownerId!.isNotEmpty &&
                                  _isLoadingStaff
                              ? 'Đang tải...'
                              : 'Chưa có nhân viên phụ trách',
                        ),
                      );

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (widget.onFacilityTap != null) {
                              widget.onFacilityTap!(facility);
                            } else {
                              context.push(
                                '/facility/${facility.id}/courts',
                                extra: facility.name,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        facility.name ?? 'Cơ sở thể thao',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isActive
                                                    ? Colors.green
                                                    : Colors.grey)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isActive
                                            ? 'ĐANG HOẠT ĐỘNG'
                                            : 'TẠM DỪNG',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.green
                                              : Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${facility.address} (${facility.description ?? 'Hà Nội'})',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Phụ trách: ${staffUser.name}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Xem danh sách sân →',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          onPressed: () => _showFormDialog(
                                            facility: facility,
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _confirmDelete(facility),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

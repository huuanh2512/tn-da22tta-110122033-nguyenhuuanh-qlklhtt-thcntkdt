import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:server_module/server_module.dart';
import '../cubit/sport/sport_management_cubit.dart';
import '../cubit/sport/sport_management_state.dart';
import '../../domain/entities/sport_catalog_entity.dart';
import '../widgets/crud_popup.dart';

class SportManagementPage extends StatefulWidget {
  final bool isEmbedded;

  const SportManagementPage({super.key, this.isEmbedded = false});

  @override
  State<SportManagementPage> createState() => _SportManagementPageState();
}

class _SportManagementPageState extends State<SportManagementPage> {
  late SportManagementCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  List<SportEntity> _allSports = [];
  List<SportEntity> _filteredSports = [];
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = SportManagementCubit(GetIt.I(), GetIt.I(), GetIt.I(), GetIt.I());
    _cubit.loadSports();
  }

  @override
  void dispose() {
    _cubit.close();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredSports = _allSports.where((s) {
        final name = (s.name ?? '').toLowerCase();
        final desc =
            (s is SportCatalogEntity ? s.description ?? '' : s.iconUrl ?? '')
                .toLowerCase();
        return name.contains(query.toLowerCase()) ||
            desc.contains(query.toLowerCase());
      }).toList();
    });
  }

  IconData _getSportIcon(String? name) {
    if (name == null) return Icons.sports;
    final lower = name.toLowerCase();
    if (lower.contains('bóng đá') ||
        lower.contains('soccer') ||
        lower.contains('football')) {
      return Icons.sports_soccer;
    } else if (lower.contains('cầu lông') || lower.contains('badminton')) {
      return Icons.sports_tennis;
    } else if (lower.contains('tennis') || lower.contains('quần vợt')) {
      return Icons.sports_tennis;
    } else if (lower.contains('bóng rổ') || lower.contains('basketball')) {
      return Icons.sports_basketball;
    } else if (lower.contains('bóng chuyền') || lower.contains('volleyball')) {
      return Icons.sports_volleyball;
    } else if (lower.contains('bóng ném') || lower.contains('handball')) {
      return Icons.sports_handball;
    } else if (lower.contains('golf')) {
      return Icons.sports_golf;
    } else if (lower.contains('bơi') || lower.contains('swim')) {
      return Icons.pool;
    } else if (lower.contains('chạy') ||
        lower.contains('run') ||
        lower.contains('điền kinh')) {
      return Icons.directions_run;
    }
    return Icons.sports;
  }

  Future<void> _showFormDialog({SportEntity? sport}) async {
    final isEdit = sport != null;
    final nameController = TextEditingController(text: sport?.name);
    BuildContext? sheetContext;
    StateSetter? setSheetState;
    var isSubmitting = false;

    String description = '';
    int teamSize = 2;
    bool active = true;
    String? iconUrl = sport?.iconUrl;
    Uint8List? selectedIconBytes;
    String? selectedIconName;
    var isUploadingIcon = false;

    if (sport != null) {
      if (sport is SportCatalogEntity) {
        description = sport.description ?? '';
        teamSize = sport.teamSize ?? 2;
        active = sport.active;
      } else {
        description = sport.iconUrl ?? '';
      }
    }

    final descController = TextEditingController(text: description);
    final teamSizeController = TextEditingController(text: teamSize.toString());

    await CrudPopup.showForm<void>(
      context,
      title: isEdit ? 'Chỉnh sửa môn thể thao' : 'Thêm môn thể thao mới',
      submitLabel: isEdit ? 'Lưu thay đổi' : 'Thêm mới',
      icon: isEdit ? Icons.edit_outlined : Icons.sports_rounded,
      barrierDismissible: false,
      builder: (context, setDialogState) {
        sheetContext = context;
        setSheetState = setDialogState;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên môn thể thao',
                hintText: 'Ví dụ: Cầu lông, Bóng đá...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Nhập mô tả tóm tắt...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teamSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượng người chơi / Đội',
                hintText: 'Ví dụ: 1, 2, 5, 11...',
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, _) {
                Future<void> selectAndUploadIcon() async {
                  final pickedFile = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1024,
                  );
                  if (pickedFile == null) return;

                  final bytes = await pickedFile.readAsBytes();
                  setDialogState(() {
                    selectedIconBytes = bytes;
                    selectedIconName = pickedFile.name;
                    isUploadingIcon = true;
                  });

                  final formData = FormData.fromMap({
                    'file': MultipartFile.fromBytes(
                      bytes,
                      filename: pickedFile.name,
                    ),
                  });
                  final response = await GetIt.I<UploadService>().uploadSingle(
                    formData,
                  );

                  if (!context.mounted) return;
                  if (response.success && response.data is Map) {
                    final raw = Map<String, dynamic>.from(response.data as Map);
                    final uploadData = raw['data'];
                    final uploadedUrl = uploadData is Map
                        ? uploadData['url']?.toString()
                        : null;
                    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                      setDialogState(() {
                        iconUrl = uploadedUrl;
                        isUploadingIcon = false;
                      });
                      return;
                    }
                  }

                  setDialogState(() => isUploadingIcon = false);
                  CrudPopup.showMessage(
                    context,
                    message:
                        response.message ?? 'Không thể tải ảnh lên máy chủ',
                    tone: CrudPopupTone.danger,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ảnh đại diện môn thể thao',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: selectedIconBytes != null
                              ? ClipOval(
                                  child: Image.memory(
                                    selectedIconBytes!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : SportIconImage(
                                  imageUrl: iconUrl,
                                  fallbackIcon: _getSportIcon(sport?.name),
                                  fallbackColor: _primaryColor,
                                  size: 48,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploadingIcon
                                ? null
                                : selectAndUploadIcon,
                            icon: isUploadingIcon
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.image_outlined),
                            label: Text(
                              isUploadingIcon
                                  ? 'Đang tải ảnh...'
                                  : selectedIconName ??
                                        (iconUrl?.isNotEmpty == true
                                            ? 'Thay đổi ảnh'
                                            : 'Chọn ảnh từ máy'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Active Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kích hoạt danh mục',
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
        );
      },
      canSubmit: () => !isUploadingIcon,
      isSubmitting: () => isSubmitting,
      onSubmit: () async {
        if (isSubmitting) return;

        final name = nameController.text.trim();
        final desc = descController.text.trim();
        final sizeText = teamSizeController.text.trim();

        if (name.isEmpty || desc.isEmpty || sizeText.isEmpty) {
          CrudPopup.showMessage(
            context,
            message: 'Vui lòng nhập đầy đủ thông tin bắt buộc',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        final size = int.tryParse(sizeText);
        if (size == null || size <= 0) {
          CrudPopup.showMessage(
            context,
            message: 'Số lượng người chơi không hợp lệ',
            tone: CrudPopupTone.warning,
          );
          return;
        }

        setSheetState?.call(() => isSubmitting = true);

        final success = isEdit
            ? await _cubit.updateSport(
                id: sport.id,
                name: name,
                description: desc,
                teamSize: size,
                active: active,
                iconUrl: iconUrl,
              )
            : await _cubit.createSport(
                name: name,
                description: desc,
                teamSize: size,
                active: active,
                iconUrl: iconUrl,
              );

        final currentSheetContext = sheetContext;
        if (success &&
            currentSheetContext != null &&
            currentSheetContext.mounted) {
          Navigator.of(currentSheetContext).pop();
          return;
        }

        if (currentSheetContext != null && currentSheetContext.mounted) {
          setSheetState?.call(() => isSubmitting = false);
        }
      },
    );

    // The route future may complete before the bottom-sheet exit animation has
    // detached its text fields. Dispose controllers after that transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    descController.dispose();
    teamSizeController.dispose();
  }

  Future<void> _confirmDelete(SportEntity sport) async {
    final confirmed = await CrudPopup.confirmDelete(
      context,
      title: 'Xác nhận xóa',
      message:
          'Bạn có chắc chắn muốn xóa môn thể thao "${sport.name}" khỏi hệ thống không?',
      cancelLabel: 'Hủy',
      confirmLabel: 'Xóa',
    );
    if (confirmed) {
      _cubit.deleteSport(sport.id);
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
                'QUẢN LÝ MÔN THỂ THAO',
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
                hintText: 'Tìm kiếm môn thể thao...',
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

          // Sports List
          Expanded(
            child: BlocConsumer<SportManagementCubit, SportManagementState>(
              bloc: _cubit,
              listener: (context, state) {
                if (state is SportManagementSuccess) {
                  CrudPopup.showMessage(
                    context,
                    message: state.message,
                    tone: CrudPopupTone.success,
                  );
                }
                if (state is SportManagementError) {
                  CrudPopup.showMessage(
                    context,
                    message: state.message,
                    tone: CrudPopupTone.danger,
                  );
                }
              },
              builder: (context, state) {
                if (state is SportManagementLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                if (state is SportManagementLoaded) {
                  _allSports = state.sports;
                  if (_searchController.text.isEmpty) {
                    _filteredSports = _allSports;
                  }
                }

                if (_filteredSports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không tìm thấy môn thể thao nào',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _cubit.loadSports(),
                  color: _primaryColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80,
                    ),
                    itemCount: _filteredSports.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final sport = _filteredSports[index];

                      String description = '';
                      int teamSize = 2;
                      bool active = true;

                      if (sport is SportCatalogEntity) {
                        description = sport.description ?? '';
                        teamSize = sport.teamSize ?? 2;
                        active = sport.active;
                      } else {
                        description = sport.iconUrl ?? '';
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon container
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (active ? _primaryColor : Colors.grey)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SportIconImage(
                                  imageUrl: sport.iconUrl,
                                  fallbackIcon: _getSportIcon(sport.name),
                                  fallbackColor: active
                                      ? _primaryColor
                                      : Colors.grey,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            sport.name ?? 'Môn thể thao',
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
                                                (active
                                                        ? Colors.green
                                                        : Colors.grey)
                                                    .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            active ? 'KÍCH HOẠT' : 'TẠM ẨN',
                                            style: TextStyle(
                                              color: active
                                                  ? Colors.green
                                                  : Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.groups_outlined,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đội hình: $teamSize người/đội',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Action Buttons Column
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showFormDialog(sport: sport),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _confirmDelete(sport),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  // Switch to toggle active status quickly
                                  Switch(
                                    value: active,
                                    activeThumbColor: _primaryColor,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      _cubit.updateSport(
                                        id: sport.id,
                                        name: sport.name ?? '',
                                        description: description,
                                        teamSize: teamSize,
                                        active: val,
                                        iconUrl: sport.iconUrl,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
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

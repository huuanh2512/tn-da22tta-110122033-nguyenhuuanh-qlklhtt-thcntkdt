import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:authentication_module/application/firebase_email_auth_flow.dart';
import 'package:notification_module/notification_module.dart';
import '../cubit/user_management_cubit.dart';
import '../cubit/user_management_state.dart';
import '../../domain/entities/user_catalog_entity.dart';

class UserManagementPage extends StatefulWidget {
  final bool isEmbedded;

  const UserManagementPage({super.key, this.isEmbedded = false});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late UserManagementCubit _cubit;
  final TextEditingController _searchController = TextEditingController();

  String _selectedRoleFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';
  String _selectedFacilityFilter = 'ALL';

  List<UserEntity> _allUsers = [];
  List<UserEntity> _filteredUsers = [];
  List<FacilityEntity> _facilities = [];
  bool _isLoadingFacilities = false;

  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = UserManagementCubit(
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
      GetIt.I(),
    );
    _cubit.loadUsers();
    _loadFacilities();
  }

  @override
  void dispose() {
    _cubit.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    if (!mounted) return;
    setState(() => _isLoadingFacilities = true);
    try {
      final useCase = GetIt.I<GetFacilitiesUseCase>();
      final response = await useCase();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _facilities = response.data!;
        });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoadingFacilities = false);
  }

  void _applyFilters() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredUsers = _allUsers.where((u) {
        // 1. Search Query Match
        final name = (u.name ?? '').toLowerCase();
        final email = (u.email ?? '').toLowerCase();
        final phone = (u is UserCatalogEntity ? u.phone ?? '' : '')
            .toLowerCase();
        final matchesQuery =
            name.contains(query) ||
            email.contains(query) ||
            phone.contains(query);

        // 2. Role Filter Match
        final matchesRole =
            _selectedRoleFilter == 'ALL' ||
            (u.role?.toUpperCase() == _selectedRoleFilter);

        // 3. Status Filter Match
        final matchesStatus =
            _selectedStatusFilter == 'ALL' ||
            (u.status?.toUpperCase() == _selectedStatusFilter);

        // 4. Facility Filter Match
        bool matchesFacility = true;
        if (_selectedFacilityFilter != 'ALL') {
          if (u is UserCatalogEntity) {
            matchesFacility =
                u.facilityId == _selectedFacilityFilter ||
                (u.facilityName != null &&
                    _facilities.any(
                      (f) =>
                          f.id == _selectedFacilityFilter &&
                          f.name == u.facilityName,
                    ));
          } else {
            matchesFacility = false;
          }
        }

        return matchesQuery && matchesRole && matchesStatus && matchesFacility;
      }).toList();
    });
  }

  void _showRoleDialog(UserEntity user) {
    String currentRole = user.role ?? 'CUSTOMER';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Thay đổi vai trò',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản: ${user.email}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: currentRole.toUpperCase(),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vai trò mới'),
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: 'CUSTOMER',
                    child: Text(
                      'CUSTOMER (Khách hàng)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'STAFF',
                    child: Text(
                      'STAFF (Nhân viên)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text(
                      'ADMIN (Quản trị viên)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => currentRole = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _cubit.updateUserRole(user.id, currentRole);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusConfirmDialog(UserEntity user) {
    final bool isLocking = user.status != 'INACTIVE';
    final String targetStatus = isLocking ? 'INACTIVE' : 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isLocking ? 'Xác nhận khóa tài khoản' : 'Mở khóa tài khoản',
        ),
        content: Text(
          isLocking
              ? 'Bạn có chắc chắn muốn khóa tài khoản "${user.email}" không? Người dùng này sẽ không thể đăng nhập.'
              : 'Mở khóa cho tài khoản "${user.email}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _cubit.updateUserStatus(user.id, targetStatus);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isLocking ? Colors.red : Colors.green,
            ),
            child: Text(
              isLocking ? 'Khóa' : 'Mở khóa',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationSheet(UserEntity user) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gửi Thông Báo Hệ Thống',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Gửi tới: ${user.name ?? user.email ?? "Người dùng"}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),

                // Tiêu đề
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề thông báo',
                    hintText: 'Nhập tiêu đề...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tiêu đề';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nội dung
                TextFormField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Nội dung thông báo',
                    hintText: 'Nhập nội dung thông báo...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập nội dung';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Nút gửi
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5600),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);

                        // Show circular loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5600),
                            ),
                          ),
                        );

                        try {
                          final useCase = GetIt.I<CreateNotificationUseCase>();
                          final response = await useCase(
                            userId: user.id,
                            title: titleController.text.trim(),
                            body: bodyController.text.trim(),
                          );

                          // Pop loading indicator
                          if (context.mounted) Navigator.pop(context);

                          if (response.success) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gửi thông báo thành công!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response.message ?? 'Lỗi khi gửi thông báo',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // pop loading
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text(
                      'Gửi Thông Báo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAssignFacilityDialog(UserEntity user) {
    String? selectedFacilityId = _facilities.isNotEmpty
        ? _facilities.first.id
        : null;

    // Tìm ID cơ sở hiện tại nếu có
    if (user is UserCatalogEntity) {
      if (user.facilityId != null && user.facilityId!.isNotEmpty) {
        selectedFacilityId = user.facilityId;
      } else {
        // So khớp ngược tìm cơ sở STAFF đang quản lý
        final matched = _facilities.firstWhere(
          (f) =>
              f.ownerId == user.id ||
              (user.facilityName != null && f.name == user.facilityName),
          orElse: () => FacilityEntity(id: ''),
        );
        if (matched.id.isNotEmpty) {
          selectedFacilityId = matched.id;
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Gán cơ sở quản lý',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhân viên: ${user.name ?? user.email}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _isLoadingFacilities
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    )
                  : _facilities.isEmpty
                  ? const Text(
                      'Không tìm thấy cơ sở nào. Vui lòng tạo cơ sở trước.',
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: selectedFacilityId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn cơ sở thể thao',
                      ),
                      dropdownColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      items: _facilities
                          .map(
                            (fac) => DropdownMenuItem(
                              value: fac.id,
                              child: Text(
                                fac.name ?? 'Cơ sở',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFacilityId = val);
                        }
                      },
                    ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: _facilities.isEmpty
                  ? null
                  : () {
                      if (selectedFacilityId != null) {
                        _cubit.assignFacility(user.id, selectedFacilityId!);
                      }
                      Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Gán cơ sở'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'STAFF';
    String? selectedFacilityId = _facilities.isNotEmpty
        ? _facilities.first.id
        : null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add_rounded,
                  color: _primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thêm Thành Viên Mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Name field
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Họ và tên *',
                      hintText: 'Nhập họ và tên...',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập Họ và tên';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Phone field
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại *',
                      hintText: 'Nhập số điện thoại...',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập Số điện thoại';
                      }
                      if (!RegExp(r'^\d{10,11}$').hasMatch(value.trim())) {
                        return 'Số điện thoại không hợp lệ (10-11 số)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email field
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'user@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập Email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value.trim())) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Người dùng sẽ nhận email để tự thiết lập mật khẩu.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Vai trò *',
                      prefixIcon: const Icon(
                        Icons.admin_panel_settings_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'STAFF',
                        child: Text(
                          'STAFF (Nhân viên)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text(
                          'ADMIN (Quản trị viên)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                  if (selectedRole == 'STAFF') ...[
                    const SizedBox(height: 16),
                    _isLoadingFacilities
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _primaryColor,
                            ),
                          )
                        : _facilities.isEmpty
                        ? const Text(
                            'Không tìm thấy cơ sở nào. Vui lòng tạo cơ sở trước.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: selectedFacilityId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Cơ sở quản lý *',
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            dropdownColor: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            items: _facilities
                                .map(
                                  (fac) => DropdownMenuItem(
                                    value: fac.id,
                                    child: Text(
                                      fac.name ?? 'Cơ sở',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedFacilityId = val);
                              }
                            },
                          ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  final provisioned = await _cubit.provisionFirebaseUser(
                    email: emailController.text.trim(),
                    role: selectedRole,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    facilityId: selectedRole == 'STAFF'
                        ? selectedFacilityId
                        : null,
                  );
                  if (!provisioned) return;
                  try {
                    await FirebaseEmailAuthFlow.sendPasswordReset(
                      emailController.text,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã gửi lời mời tạo tài khoản. Người dùng cần thiết lập mật khẩu qua email, sau đó đăng nhập và xác nhận email để kích hoạt tài khoản.',
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tài khoản đã được tạo nhưng chưa gửi được email thiết lập mật khẩu.',
                          ),
                          action: SnackBarAction(
                            label: 'Gửi lại email',
                            onPressed: () {
                              FirebaseEmailAuthFlow.sendPasswordReset(
                                emailController.text,
                              );
                            },
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Đăng ký',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedRoleFilter == value;
    final isDark = theme.brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
      ),
      onSelected: (selected) {
        setState(() {
          _selectedRoleFilter = value;
          // Reset facility filter if role is changed from staff and not ALL
          if (value != 'STAFF' && value != 'ALL') {
            _selectedFacilityFilter = 'ALL';
          }
          _applyFilters();
        });
      },
      backgroundColor: isDark ? const Color(0x1AFFFFFF) : Colors.grey.shade100,
      selectedColor: _primaryColor,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? _primaryColor
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text(
                'QUẢN LÝ THÀNH VIÊN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, sđt...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
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

          // 2. ChoiceChips for Role Filtering
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                _buildRoleChip('ALL', 'Tất cả', Icons.group),
                const SizedBox(width: 8),
                _buildRoleChip('ADMIN', 'Admin', Icons.admin_panel_settings),
                const SizedBox(width: 8),
                _buildRoleChip('STAFF', 'Staff', Icons.badge),
                const SizedBox(width: 8),
                _buildRoleChip('CUSTOMER', 'Khách', Icons.person),
              ],
            ),
          ),

          // 3. Dropdowns Row (Status & Facility)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                // Status Filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        dropdownColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        isExpanded: true,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text(
                              'Tất cả trạng thái',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ACTIVE',
                            child: Text(
                              'Đang hoạt động',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'INACTIVE',
                            child: Text(
                              'Đang bị khóa',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatusFilter = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // Show facility filter if role is STAFF or ALL
                if (_selectedRoleFilter == 'STAFF' ||
                    _selectedRoleFilter == 'ALL') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFacilityFilter,
                          dropdownColor: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          isExpanded: true,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text(
                                'Tất cả cơ sở',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            ..._facilities.map(
                              (fac) => DropdownMenuItem(
                                value: fac.id,
                                child: Text(
                                  fac.name ?? 'Cơ sở',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedFacilityFilter = val);
                              _applyFilters();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. User List
          Expanded(
            child: BlocConsumer<UserManagementCubit, UserManagementState>(
              bloc: _cubit,
              listener: (context, state) {
                if (state is UserManagementSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadFacilities(); // Tải lại cơ sở để cập nhật liên kết mới nhất
                }
                if (state is UserManagementError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is UserManagementLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                if (state is UserManagementLoaded) {
                  _allUsers = state.users;
                  // Cập nhật filter trực tiếp để tránh render với dữ liệu cũ
                  final query = _searchController.text.toLowerCase();
                  _filteredUsers = _allUsers.where((u) {
                    final name = (u.name ?? '').toLowerCase();
                    final email = (u.email ?? '').toLowerCase();
                    final phone = (u is UserCatalogEntity ? u.phone ?? '' : '')
                        .toLowerCase();
                    final matchesQuery =
                        name.contains(query) ||
                        email.contains(query) ||
                        phone.contains(query);
                    final matchesRole =
                        _selectedRoleFilter == 'ALL' ||
                        (u.role?.toUpperCase() == _selectedRoleFilter);
                    final matchesStatus =
                        _selectedStatusFilter == 'ALL' ||
                        (u.status?.toUpperCase() == _selectedStatusFilter);

                    bool matchesFacility = true;
                    if (_selectedFacilityFilter != 'ALL') {
                      if (u is UserCatalogEntity) {
                        matchesFacility =
                            u.facilityId == _selectedFacilityFilter ||
                            (u.facilityName != null &&
                                _facilities.any(
                                  (f) =>
                                      f.id == _selectedFacilityFilter &&
                                      f.name == u.facilityName,
                                ));
                      } else {
                        matchesFacility = false;
                      }
                    }

                    return matchesQuery &&
                        matchesRole &&
                        matchesStatus &&
                        matchesFacility;
                  }).toList();
                }

                if (_filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không tìm thấy thành viên nào',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _cubit.loadUsers(),
                  color: _primaryColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 80,
                      top: 8,
                    ),
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isStaff = user.role?.toUpperCase() == 'STAFF';
                      final isAdmin = user.role?.toUpperCase() == 'ADMIN';
                      final isActive = user.status?.toUpperCase() != 'INACTIVE';

                      String? facilityName;
                      String? phone;

                      if (user is UserCatalogEntity) {
                        facilityName = user.facilityName;
                        if (facilityName == null || facilityName.isEmpty) {
                          // 1. Thử tra cứu bằng facilityId
                          if (user.facilityId != null &&
                              user.facilityId!.isNotEmpty) {
                            final matched = _facilities.firstWhere(
                              (f) => f.id == user.facilityId,
                              orElse: () => FacilityEntity(id: ''),
                            );
                            if (matched.id.isNotEmpty) {
                              facilityName = matched.name;
                            }
                          }
                          // 2. So khớp ngược tìm cơ sở STAFF đang quản lý
                          if (facilityName == null || facilityName.isEmpty) {
                            final matched = _facilities.firstWhere(
                              (f) => f.ownerId == user.id,
                              orElse: () => FacilityEntity(id: ''),
                            );
                            if (matched.id.isNotEmpty) {
                              facilityName = matched.name;
                            }
                          }
                        }
                        phone = user.phone;
                      }

                      // Màu sắc và nhãn của vai trò
                      Color roleColor = Colors.blue;
                      if (isAdmin) roleColor = Colors.red;
                      if (isStaff) roleColor = Colors.green;

                      final displayName =
                          (user.name != null && user.name!.trim().isNotEmpty)
                          ? user.name!.trim()
                          : (user.email != null &&
                                user.email!.trim().isNotEmpty)
                          ? user.email!.trim()
                          : 'U';
                      final initialLetter = displayName
                          .substring(0, 1)
                          .toUpperCase();

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: roleColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    backgroundImage:
                                        user.avatar != null &&
                                            user.avatar!.startsWith('http')
                                        ? NetworkImage(user.avatar!)
                                        : null,
                                    child:
                                        user.avatar == null ||
                                            !user.avatar!.startsWith('http')
                                        ? Text(
                                            initialLetter,
                                            style: TextStyle(
                                              color: roleColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),

                                  // Email & Name Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name ?? 'Thành viên mới',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (phone != null &&
                                            phone.trim().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 10,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  phone,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 11,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Status & Role Badges
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          user.role?.toUpperCase() ??
                                              'CUSTOMER',
                                          style: TextStyle(
                                            color: roleColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (isActive
                                                      ? Colors.green
                                                      : Colors.red)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          isActive ? 'HOẠT ĐỘNG' : 'BỊ KHÓA',
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isStaff) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (facilityName != null &&
                                                            facilityName
                                                                .isNotEmpty
                                                        ? Colors.teal
                                                        : Colors.orange)
                                                    .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            facilityName != null &&
                                                    facilityName.isNotEmpty
                                                ? 'ĐÃ GÁN CƠ SỞ'
                                                : 'CHƯA GÁN CƠ SỞ',
                                            style: TextStyle(
                                              color:
                                                  facilityName != null &&
                                                      facilityName.isNotEmpty
                                                  ? Colors.teal
                                                  : Colors.orange.shade900,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),

                              // Facility assignment text for staff
                              if (isStaff) ...[
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.business_outlined,
                                            size: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              facilityName != null &&
                                                      facilityName.isNotEmpty
                                                  ? 'Cơ sở: ${facilityName.toUpperCase()}'
                                                  : 'Chưa được phân công cơ sở',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: facilityName != null
                                                    ? (isDark
                                                          ? Colors
                                                                .tealAccent
                                                                .shade400
                                                          : Colors
                                                                .teal
                                                                .shade700)
                                                    : Colors.orange.shade800,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_location_alt_outlined,
                                        color: Colors.teal,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _showAssignFacilityDialog(user),
                                      tooltip: 'Gán cơ sở',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              ],

                              const Divider(height: 20),

                              // Quick Management Actions Row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: [
                                  // Send Notification Button
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showNotificationSheet(user),
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Gửi thông báo',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange.shade800,
                                      side: BorderSide(
                                        color: Colors.orange.shade200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),

                                  // Change Role Button
                                  OutlinedButton.icon(
                                    onPressed: () => _showRoleDialog(user),
                                    icon: const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Phân quyền',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue.shade800,
                                      side: BorderSide(
                                        color: Colors.blue.shade100,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),

                                  // Lock / Unlock Button
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showStatusConfirmDialog(user),
                                    icon: Icon(
                                      isActive
                                          ? Icons.lock_outline
                                          : Icons.lock_open_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      isActive ? 'Khóa acc' : 'Mở khóa',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isActive
                                          ? Colors.red
                                          : Colors.green,
                                      side: BorderSide(
                                        color: isActive
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
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

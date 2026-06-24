# PROJECT RULES

> Lưu ý: file này hiện đang chứa rule Flutter/Dart được copy sang project web. Khi làm `react-staff-admin`, dùng `../RULES.md` để chọn nguồn rule đúng và ưu tiên `crm_website.md` cho React/TypeScript.

## 1. TƯ DUY KIẾN TRÚC (STRICT CLEAN ARCHITECTURE)

### 1.1 KIẾN TRÚC BẮT BUỘC

Mọi feature BẮT BUỘC tuân thủ cấu trúc:

```text
features/
└── feature_name/
    ├── data/
    │   ├── datasources/
    │   │   ├── remote/
    │   │   └── local/
    │   │
    │   ├── models/
    │   ├── repositories/
    │   └── mappers/
    │
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    │
    ├── presentation/
    │   ├── bloc/
    │   ├── pages/
    │   └── widgets/
    │
    └── di/
```

KHÔNG ĐƯỢC:

* tạo folder không rõ mục đích
* để file loose ngoài feature
* đặt business logic trong UI
* import chéo sai layer

---

### 1.2 DEPENDENCY RULE (QUY TẮC PHỤ THUỘC)

CHỈ ĐƯỢC PHÉP:

```text
Presentation → Domain
Data → Domain
```

TUYỆT ĐỐI CẤM:

```text
Domain → Flutter
Domain → Dio
Domain → Bloc
Domain → Data
Presentation → Data
Presentation → Datasource
```

Domain phải là Pure Dart 100%.

---

### 1.3 DOMAIN LAYER (LỚP NGHIỆP VỤ)

#### MỤC TIÊU

Domain là trái tim hệ thống:

* không phụ thuộc framework
* không chứa UI
* không chứa API
* không chứa JSON parsing

---

#### entities/

QUY TẮC:

* dùng `Equatable`
* immutable (`final`)
* constructor `const`
* KHÔNG `fromJson/toJson`
* KHÔNG extends Model
* KHÔNG import Flutter package

VÍ DỤ ĐÚNG:

```dart
class User extends Equatable {
  final String id;
  final String name;

  const User({
    required this.id,
    required this.name,
  });

  @override
  List<Object> get props => [id, name];
}
```

---

#### repositories/

QUY TẮC:

* chỉ là abstract class
* không chứa implementation
* không chứa Dio/API logic

VÍ DỤ ĐÚNG:

```dart
abstract class AuthRepository {
  Future<User> login({
    required String email,
    required String password,
  });
}
```

---

#### usecases/

QUY TẮC:

* mỗi usecase chỉ xử lý 1 business logic
* không viết usecase đa nhiệm
* không gọi Dio trực tiếp
* luôn gọi qua Repository

MỖI FILE = 1 USECASE

VÍ DỤ ĐÚNG:

```dart
class LoginUseCase {
  final AuthRepository repository;

  const LoginUseCase(this.repository);

  Future<User> call(LoginParams params) {
    return repository.login(
      email: params.email,
      password: params.password,
    );
  }
}
```

---

### 1.4 DATA LAYER

#### MỤC TIÊU

Data layer chỉ xử lý:

* API
* Cache
* JSON
* DTO
* Repository implementation

KHÔNG chứa business logic phức tạp.

---

#### models/

QUY TẮC:

* Model kế thừa Entity
* chứa:

  * `fromJson`
  * `toJson`
* không chứa UI logic

VÍ DỤ ĐÚNG:

```dart
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
```

---

#### datasources/

##### remote/

CHỈ ĐƯỢC:

* gọi API
* parse response
* throw exception

KHÔNG ĐƯỢC:

* xử lý business logic
* gọi Bloc
* xử lý UI

VÍ DỤ ĐÚNG:

```dart
abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
  });
}
```

---

#### repositories/

QUY TẮC:

* implement repository từ domain
* convert Model ↔ Entity
* quyết định lấy local hay remote

KHÔNG ĐƯỢC:

* viết UI logic
* import presentation

VÍ DỤ ĐÚNG:

```dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  const AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<User> login({
    required String email,
    required String password,
  }) {
    return remoteDataSource.login(
      email: email,
      password: password,
    );
  }
}
```

---

### 1.5 PRESENTATION LAYER

#### MỤC TIÊU

Presentation chỉ xử lý:

* UI
* State management
* user interaction

KHÔNG xử lý:

* API
* Dio
* JSON
* business logic lớn

---

#### bloc/

QUY TẮC:

* Bloc chỉ gọi UseCase
* không gọi API trực tiếp
* không import datasource

FLOW BẮT BUỘC:

```text
UI
→ Bloc
→ UseCase
→ Repository
→ Datasource
```

---

#### pages/

QUY TẮC:

* chỉ layout UI
* không chứa logic phức tạp
* tách widget nhỏ nếu file > 300 dòng

TUYỆT ĐỐI CẤM:

```dart
final response = await dio.get(...);
```

---

#### widgets/

QUY TẮC:

* reusable
* stateless ưu tiên
* không chứa business logic

---

### 1.6 STATE MANAGEMENT RULES

BẮT BUỘC:

* dùng Bloc/Cubit
* state immutable
* event/state tách file rõ ràng

KHÔNG ĐƯỢC:

* emit trong UI
* xử lý async trực tiếp trong widget

---

### 1.7 ERROR HANDLING

QUY TẮC BẮT BUỘC

Data layer:

* throw Exception/Failure

Domain layer:

* xử lý bằng Either<Failure, Data>

Presentation:

* không try-catch API trực tiếp

---

### 1.8 DEPENDENCY INJECTION

BẮT BUỘC:

* dùng GetIt
* inject qua constructor
* không new class trực tiếp trong UI

CẤM:

```dart
final repo = AuthRepositoryImpl();
```

trong Bloc/Page.

---

### 1.9 FEATURE ISOLATION

QUY TẮC:
Mỗi feature phải độc lập.

KHÔNG ĐƯỢC:

```text
auth phụ thuộc profile
profile phụ thuộc home
home phụ thuộc auth
```

Nếu cần dùng chung:

* đưa vào `core`
* hoặc `shared`

---

### 1.10 CORE LAYER

#### core/

Chỉ chứa:

* constants
* themes
* network
* errors
* utils
* base classes

KHÔNG chứa:

* feature business logic

---

### 1.11 QUY TẮC FILE

BẮT BUỘC:

* 1 class chính / 1 file
* tên file snake_case
* tên class PascalCase

---

### 1.12 CLEAN CODE ENFORCEMENT

HÀM:

* tối đa ~30 dòng
* tách private method nếu dài

UI:

* widget lớn phải tách nhỏ

KHÔNG HARDCODE:

* text
* endpoint
* colors
* spacing

---

### 1.13 ASYNC/AWAIT RULES

BẮT BUỘC:

* mọi async phải dùng `async/await`
* tránh `.then()`

KHÔNG ĐƯỢC:

```dart
api.get().then(...)
```

---

### 1.14 IMPORT RULES

KHÔNG wildcard import

SAI:

```dart
import 'package:abc/*';
```

ƯU TIÊN:

* relative import nội bộ feature
* package import cho external package

---

### 1.15 TESTABILITY RULES

Code phải dễ unit test:

* repository dùng abstract
* usecase độc lập
* không phụ thuộc UI

---

### 1.16 QUY TẮC FLOW CHUẨN

FLOW CHUẨN BẮT BUỘC

```text
Page
→ Bloc/Cubit
→ UseCase
→ Repository(Abstract)
→ RepositoryImpl
→ DataSource
→ API/Local DB
```

---

### 1.17 NHỮNG ĐIỀU TUYỆT ĐỐI CẤM

CẤM:

* gọi API trong UI
* import Data vào Presentation
* import Flutter vào Domain
* business logic trong Widget
* dùng BuildContext trong Bloc
* dùng static state global
* dùng singleton tự tạo thủ công
* để TODO chưa xử lý
* code chết/comment code cũ

---

## 2. QUY TẮC CODE (CODING STANDARDS)

* Ngôn ngữ: Phản hồi bằng Tiếng Việt.
* Clean Code:

  * Code phải dễ đọc.
  * Logic rõ ràng.
  * Chia nhỏ các hàm (dưới 30 dòng).
* Scalability:

  * Luôn ưu tiên khả năng mở rộng.
  * Tránh hardcode.
* Best Practices:

  * Dùng Null Safety nghiêm ngặt.
  * Không sử dụng APIs Deprecated.
  * Ưu tiên `const` constructor.
  * Ưu tiên `final` variables.
* Dependencies:

  * Chỉ dùng thư viện thiết yếu:

    * dartz
    * equatable
    * flutter_bloc
    * dio

---

## 3. CÁC ĐIỀU CẤM KỴ (HARD RULES)

### QUY TẮC CỨNG

Tuyệt đối KHÔNG ĐƯỢC:

* chỉnh sửa
* thay đổi
* refactor

bất kỳ code nào trong thư mục:

```text
server_module/
```

---

KHÔNG ĐƯỢC:

* gọi API trực tiếp trong UI (`pages`)
* bypass UseCase
* import Datasource vào Bloc/Page
* tạo singleton thủ công
* để file thừa/folder không rõ mục đích

Mọi request BẮT BUỘC đi qua:

```text
Bloc
→ UseCase
→ Repository
→ Datasource
```

---

## 4. QUẢN LÝ NGỮ CẢNH (CONTEXT MANAGEMENT)

### NHẬT KÝ

Sau khi hoàn thành task hoặc kết thúc phiên làm việc, BẮT BUỘC cập nhật:

```text
development_log.md
```

Format:

```text
[Ngày] - [Task đã làm] - [Trạng thái]
```

Nếu chưa có file thì phải tạo mới ở thư mục root.

---

### TIẾT KIỆM TÀI NGUYÊN

* Chỉ trỏ file (`@`) khi thực sự cần thiết.
* Luôn lên kế hoạch (Plan mode) trước khi thực hiện thay đổi lớn.
* Nếu mất ngữ cảnh:

  * đọc `@roadmap.md`
  * đọc `@development_log.md`

KHÔNG tự scan toàn bộ project.

---

## 5. QUY TRÌNH LÀM VIỆC

### BẮT BUỘC THỰC HIỆN ĐÚNG THỨ TỰ:

1. Đọc `rule.md`
2. Kiểm tra `roadmap.md`
3. Lập kế hoạch thực hiện
4. Triển khai code đúng Clean Architecture
5. Update `development_log.md`

---

## 6. TỐI ƯU HÓA QUOTA (RESOURCE OPTIMIZATION)

### LAZY CONTEXT

KHÔNG ĐƯỢC:

* scan toàn bộ project
* đọc toàn bộ source code
* list tất cả file

trừ khi được yêu cầu rõ ràng.

Chỉ đọc:

* file liên quan
* file được trỏ bằng `@`

---

### PLAN-FIRST

Trước khi sửa code:

* phải nêu kế hoạch ngắn gọn
* tối đa 1-2 câu
* xác nhận hướng xử lý trước khi act

---

### COMPACT THINKING

* Trả lời ngắn gọn.
* Đi thẳng vấn đề kỹ thuật.
* Không giải thích lan man.

---

### NO REDUNDANT READS

Khi đã có:

* `roadmap.md`
* `development_log.md`

thì KHÔNG ĐƯỢC yêu cầu:

* liệt kê toàn bộ project
* scan lại source code

trừ khi thực sự cần thiết.

---

### ERROR HANDLING RULE

Nếu gặp lỗi:

* chỉ đọc file lỗi
* chỉ đọc stack trace
* chỉ đọc file liên quan trực tiếp

KHÔNG scan toàn bộ project để tìm lỗi.

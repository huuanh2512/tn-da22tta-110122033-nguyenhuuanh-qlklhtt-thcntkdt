# Flutter Mobile Rules

Rule chinh cho `sports_management`. Muc tieu la giu code de doc, dung Clean Architecture, va tiet kiem ngu canh khi Codex lam viec.

## Kien truc bat buoc

Moi feature nen theo cau truc:

```text
features/feature_name/
  data/
    datasources/
    models/
    repositories/
    mappers/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    bloc/
    pages/
    widgets/
  di/
```

Dependency hop le:

```text
Presentation -> Domain
Data -> Domain
```

Cam:

- Domain import Flutter, Dio, Bloc, Data layer, UI, JSON parser.
- Presentation import Datasource/Service API truc tiep.
- UI goi Dio/API truc tiep.
- Bloc/Cubit dung `BuildContext`.
- Tao repository/datasource/usecase truc tiep trong Page/Widget.
- De business logic lon trong Widget/Page.
- Sua code trong `server_module/` neu task khong yeu cau ro.

## Flow request

Tat ca request phai di theo flow:

```text
Page/Widget
-> Bloc/Cubit
-> UseCase
-> Repository abstract
-> RepositoryImpl
-> DataSource/Service
-> API/Local DB
```

## Domain

- Pure Dart 100%.
- Entity immutable, uu tien `const`, `final`, `Equatable`.
- Entity khong co `fromJson/toJson`.
- Repository trong domain chi la abstract class.
- UseCase xu ly mot y nghia nghiep vu ro rang va goi repository abstract.

## Data

- Model co the ke thua/entity-map tu Entity va chua `fromJson/toJson`.
- Datasource/Service chi goi API, parse response, throw exception/failure phu hop.
- RepositoryImpl map Model <-> Entity va quyet dinh remote/local khi can.
- Khong dat UI logic hoac business flow phuc tap trong data layer.

## Presentation

- Bloc/Cubit chi goi UseCase.
- State immutable; tach event/state ro rang neu dung Bloc.
- Page chu yeu layout va dieu phoi UI event.
- Widget nen nho, reusable, uu tien stateless khi co the.
- Neu file UI qua lon, tach widget/private method co y nghia.

## Coding standards

- Phan hoi bang Tieng Viet.
- Dung Null Safety nghiem ngat.
- Uu tien `const`, `final`, `async/await`.
- Tranh `.then()` cho flow async phuc tap.
- Ten file snake_case, class PascalCase.
- Khong hardcode endpoint, text, color, spacing neu da co constants/theme.
- Khong de TODO mo ho, dead code, comment code cu.

## Error handling

- Data layer throw exception/failure ro nghia.
- Domain xu ly qua Failure/Either neu module dang dung pattern nay.
- Presentation khong try-catch API truc tiep; hien thi loi tu state.

## Context workflow

- Truoc khi sua lon: doc file lien quan, neu can thi doc `roadmap.md` va `development_log.md`.
- Khong scan toan project khi task chi cham mot module.
- Khi gap loi: doc stack trace va file lien quan truc tiep truoc.
- Sau thay doi nghiep vu/kien truc dang ke: cap nhat `development_log.md`.

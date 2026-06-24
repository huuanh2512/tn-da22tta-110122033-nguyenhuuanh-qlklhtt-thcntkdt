# server_module Summary

`modules/server_module` la package Flutter/Dart dung chung cho data/API/domain model cua app. File nay la ban tom tat de Codex dinh huong nhanh; khi can chi tiet, doc truc tiep file Dart lien quan trong `modules/server_module/lib`.

## Vai tro

- Cau hinh API client bang Dio.
- Luu/cap token thong qua token provider registry.
- Dinh nghia model/data DTO cho auth, booking, court, facility, notification, payment, review, sport, user, content.
- Dinh nghia entity va repository abstract phia domain.
- Cung cap service remote goi REST API.

## Cau truc quan trong

```text
modules/server_module/lib/
  core/
    api_config.dart
    auth_token_provider_registry.dart
    dio_client.dart
  data/
    models/
    remote/services/
  domain/
    entities/
    repositories/
  exceptions/
  server_module.dart
```

## Core

- `api_config.dart`: Base URL va endpoint/config API.
- `auth_token_provider_registry.dart`: Noi dang ky/cung cap access token cho Dio/interceptor.
- `dio_client.dart`: Tao Dio client, gan headers, xu ly network/error/token theo pattern cua module.

## Data models

Nhom model chinh:

- Auth: `auth_register_request.dart`, `auth_sign_in_request.dart`.
- Base response: `base_response.dart`.
- Booking: `booking_model.dart`.
- Court/facility/sport: `court_model.dart`, `facility_model.dart`, `sport_model.dart`.
- Notification/payment/review/user/content: cac file model tuong ung.

Nguyen tac:

- Model chiu trach nhiem JSON mapping.
- Khong dat UI logic trong model.
- Neu API response thay doi, sua model/mapper/service lien quan va doi chieu `api-admin-staff.md`.

## Remote services

Service API nam trong `data/remote/services/`:

- `auth_service.dart`
- `booking_service.dart`
- `content_service.dart`
- `court_service.dart`
- `facility_service.dart`
- `notification_service.dart`
- `payment_service.dart`
- `review_service.dart`
- `sport_service.dart`
- `upload_service.dart`
- `user_service.dart`

Nguyen tac:

- Service chi goi API va parse response.
- Khong import UI/Bloc.
- Khong chua business flow phuc tap cua presentation.
- Upload dung multipart/form-data.
- Endpoint/request/response phai doi chieu `api-admin-staff.md` khi sua.

## Domain

Entity:

- `booking_entity.dart`, `court_entity.dart`, `facility_entity.dart`, `notification_entity.dart`, `payment_entity.dart`, `review_entity.dart`, `sport_entity.dart`, `user_entity.dart`, `emoji_entity.dart`, `helpdesk_entity.dart`.

Repository abstract:

- `auth_repository.dart`, `booking_repository.dart`, `content_repository.dart`, `court_repository.dart`, `facility_repository.dart`, `notification_repository.dart`, `payment_repository.dart`, `review_repository.dart`, `sport_repository.dart`, `user_repository.dart`.

Nguyen tac:

- Domain khong import Flutter/Dio/UI.
- Repository domain chi khai bao contract.
- Neu feature module can data, goi qua repository/usecase, khong goi service truc tiep tu UI.

## Khi nao doc file nao

| Task | Doc truoc |
| --- | --- |
| Loi auth/token/header | `core/dio_client.dart`, `core/auth_token_provider_registry.dart`, `data/remote/services/auth_service.dart` |
| Loi booking/slot | `booking_service.dart`, `booking_model.dart`, `booking_entity.dart`, `api-admin-staff.md` |
| Loi facility/court/sport | service/model/entity tuong ung va `api-admin-staff.md` |
| Loi payment | `payment_service.dart`, `payment_model.dart`, `payment_entity.dart` |
| Loi notification | `notification_service.dart`, `notification_model.dart`, `notification.md` |
| Loi user/profile/role | `user_service.dart`, `user_model.dart`, `user_entity.dart` |

## Khong nen dua vao doc nay

- Khong copy lai `.dart_tool`, `pubspec.lock`, IDE metadata vao tai lieu agent.
- Khong dump source code dai vao Markdown; Codex se doc file Dart truc tiep khi can.

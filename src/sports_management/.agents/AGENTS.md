# Codex Context Entry

Doc nay la diem vao ngan gon cho Codex khi lam viec trong project Flutter `sports_management`.

## Thu tu doc

1. Doc file nay truoc.
2. Neu can rule kien truc: doc `rule.md`.
3. Neu can tong quan/uu tien tai lieu: doc `RULES.md`.
4. Neu task dung man hinh/UI/navigation: doc `UI_Specification.md` va `manhinh.md`.
5. Neu task dung API/request/response: doc `api-admin-staff.md`; can vi du JSON thi doc `json-in-out.md`.
6. Neu task dung notification: doc `notification.md` va `describe-notification-all in mobile app.md`.
7. Neu task dung matching/ghep tran: doc `matching.md` va `trienkhai.md`.
8. Neu can lich su quyet dinh: doc `development_log.md`.

## Quy tac bat buoc

- Tra loi va ghi chu lam viec bang Tieng Viet.
- Mobile Flutter theo Clean Architecture: `presentation -> domain`, `data -> domain`.
- UI khong goi API truc tiep. Luong dung: Page/Widget -> Bloc/Cubit -> UseCase -> Repository abstract -> RepositoryImpl -> DataSource/Service.
- Domain la Pure Dart: khong import Flutter, Dio, Bloc, Data layer, UI, JSON parsing.
- Bloc/Cubit khong dung `BuildContext`, khong import datasource/service API.
- Khong sua code trong `server_module/` neu task khong yeu cau ro.
- Khong scan toan project khi chua can; chi doc file lien quan den task.

## Ban do tai lieu

| File | Khi nao doc |
| --- | --- |
| `rule.md` | Rule Flutter/Clean Architecture hang ngay. |
| `RULES.md` | Index rule, cach xu ly mau thuan giua docs. |
| `roadmap.md` | Tong quan module va trang thai san pham. |
| `UI_Specification.md` | UI/state flow/widget cho cac man hinh chinh. |
| `manhinh.md` | Navigation, route, guard, bottom navigation. |
| `server_module.md` | Tom tat cau truc data/API module Flutter. |
| `api-admin-staff.md` | Contract API day du. |
| `json-in-out.md` | Vi du request/response JSON. |
| `notification.md` | Backend/web notification, Socket.IO, FCM. |
| `describe-notification-all in mobile app.md` | Payload va deep link notification tren mobile. |
| `matching.md` | Spec ghep tran/backend/API/socket/FCM. |
| `trienkhai.md` | Huong dan frontend cho matching. |
| `crm_web_specification.md` | Chi doc khi task lien quan CRM web React. |
| `development_log.md` | Lich su task, loi da sua, quyet dinh truoc do. |

## Ghi chu

- Cac file spec dai la tai lieu tra cuu, khong can doc het moi lan.
- Neu doc bi mau thuan voi code hien tai, uu tien code/test dang chay va ghi ro gia dinh khi sua.

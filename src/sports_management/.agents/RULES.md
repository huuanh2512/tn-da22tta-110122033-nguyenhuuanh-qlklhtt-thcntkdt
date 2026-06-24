# Rules Index

File nay gom rule doc tai lieu cho Codex trong workspace. Khi bat dau mot task, uu tien doc `AGENTS.md`; chi mo them file chi tiet neu task can.

## Thu tu uu tien

1. Code hien tai va test dang chay.
2. Contract/API trong project dang sua.
3. Rule kien truc cua nen tang dang sua.
4. Spec UI/nghiep vu lien quan truc tiep.
5. `development_log.md` neu can lich su quyet dinh.

## Rule chinh theo pham vi

| Pham vi | File can doc | Vai tro |
| --- | --- | --- |
| Flutter mobile | `rule.md` | Clean Architecture, Bloc/Cubit, DI, error handling. |
| UI/navigation mobile | `UI_Specification.md`, `manhinh.md` | Man hinh, route, guard, state flow. |
| API mobile/admin-staff | `api-admin-staff.md`, `json-in-out.md` | Endpoint, request/response, error code. |
| Notification | `notification.md`, `describe-notification-all in mobile app.md` | Socket.IO, FCM, payload, deep link. |
| Matching | `matching.md`, `trienkhai.md` | Ghep tran, queue, socket event, frontend flow. |
| CRM Web | `crm_web_specification.md` | Chi dung khi task lien quan React CRM. |

## Rule cung

- Mobile Flutter phai theo Clean Architecture: `domain`, `data`, `presentation`, `di`.
- Dependency chi duoc di vao Domain: Presentation -> Domain, Data -> Domain.
- Domain la Pure Dart; khong import Flutter/Dio/Bloc/Data/UI.
- UI khong goi API truc tiep; request di qua Bloc/Cubit -> UseCase -> Repository -> Datasource/Service.
- Bloc/Cubit chi goi UseCase, khong dung `BuildContext`.
- Khong tao Repository/Datasource/UseCase truc tiep trong UI; dung dependency injection.
- Request can `Authorization: Bearer <accessToken>` tru public/auth endpoint.
- Upload API dung `multipart/form-data`.
- Response API phai map dung shape thuc te; khong mac dinh moi thu boc trong `data`.
- Sau task quan trong, cap nhat `development_log.md` neu co thay doi kien truc/nghiep vu dang ke.

## Nghiep vu can nho

- Staff dat ho customer phai truyen `userId` cua customer khi tao booking.
- Tao booking can `courtId`, `bookingDate` dang `yyyy-MM-dd`, ngay khong duoc trong qua khu.
- Slot config hop le khi gio dong cua sau gio mo cua, tong thoi gian toi thieu 120 phut, tong phut chia het cho do dai slot.
- Luong thanh toan tai quay: tao booking -> tao payment -> confirm payment success -> confirm booking.
- Notification foreground chi hien in-app; background/terminated mo man hinh chi tiet theo payload khi user bam thong bao.
- Matching chi danh cho CUSTOMER co JWT hop le; host khong duoc join phong cua minh; chi host duoc duyet/tu choi thanh vien.

## Xu ly mau thuan

1. Uu tien code/test dang chay.
2. Uu tien file nam gan project dang sua hon ban mirror o project khac.
3. Rule kien truc uu tien hon spec UI neu spec UI yeu cau sai dependency.
4. Tai lieu moi hon trong `development_log.md` uu tien khi cung pham vi.
5. Neu van mau thuan, ghi ro gia dinh trong thay doi.

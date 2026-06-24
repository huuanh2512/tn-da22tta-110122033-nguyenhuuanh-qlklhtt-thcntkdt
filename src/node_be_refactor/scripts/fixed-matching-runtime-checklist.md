# Fixed Matching Schedule Runtime Smoke Test Report

## Scope

- Muc tieu: kiem thu runtime toan bo Fixed Matching Schedule tren app/backend sau cac phase da sua.
- Khong can token that trong file nay. Khi chay thu cong, dang nhap bang user test tren app hoac Postman collection noi bo.
- Khong doc, in, hoac chinh `.env`.
- Khong them nghiep vu moi trong luc test. Neu fail, ghi lai API, response, id lich/booking/session/payment va thoi diem test.

## API lien quan

| Flow | Method | Endpoint |
| --- | --- | --- |
| Tao fixed schedule | `POST` | `/api/v1/fixed-schedule` |
| Danh sach/chi tiet fixed schedule | `GET` | `/api/v1/fixed-schedule` |
| Duyet fixed schedule neu can | `PUT` | `/api/v1/fixed-schedule/:id/approve` |
| Tu choi fixed schedule | `PUT` | `/api/v1/fixed-schedule/:id/reject` |
| Join fixed matching template/fixed team setup | `POST` | `/api/v1/fixed-schedule/:id/matching/join` |
| Leave fixed matching template | `POST` | `/api/v1/fixed-schedule/:id/matching/leave` |
| Join one generated occurrence | `POST` | `/api/v1/matching/:id/join` |
| Pause series | `PUT` | `/api/v1/fixed-schedule/:id/pause` |
| Resume series | `PUT` | `/api/v1/fixed-schedule/:id/resume` |
| Cancel one occurrence | `POST` | `/api/v1/fixed-schedule/:id/occurrences/:date/cancel` |
| Cancel series | `PUT` | `/api/v1/fixed-schedule/:id/cancel` |
| Booking calendar/history | `GET` | `/api/v1/booking` |
| Booking detail | `GET` | `/api/v1/booking/:id` |

## Du lieu mau nen chuan bi

- Sport: Bong da san 5, `team_size = 5` neu sport co field nay.
- Court: 1 san ACTIVE, co gia theo gio, khung gio trong tuong lai chua co booking trung.
- Host A: customer tao lich, dai dien Team A.
- User B: customer dai dien Team B.
- Outsider C: customer khong tham gia lich.
- Staff/Admin: user co quyen quan ly co so cua court.
- Lich test: chon ngay bat dau trong tuong lai gan, lap hang tuan, co it nhat 3 occurrence tuong lai trong vong cron quet.
- Payment policy chinh: `TEAM_REPRESENTATIVES_SPLIT`.
- Neu can test Payment SUCCESS: chi cap nhat payment test bang cong cu admin/dev DB rieng, khong dung tien that.

## Checklist thu cong

### A. Tao fixed matching template

- [ ] Host A tao lich co dinh `type = MATCHING`.
- [ ] Chon `team_mode = TEAM_VS_TEAM`, `team_size = 5`.
- [ ] Chon `host_team_code = A`, `host_represented_count = 5`.
- [ ] Chon `payment_policy = TEAM_REPRESENTATIVES_SPLIT`.
- [ ] Neu flow yeu cau duyet, Staff/Admin duyet lich thanh `ACTIVE`.
- [ ] Mo chi tiet/list fixed schedule tren app.

Ket qua mong doi:

- FixedSchedule co `type = MATCHING`.
- `matchingConfig.teamMode = TEAM_VS_TEAM`.
- Team A hien thi `5/5`, Team B hien thi `0/5`.
- `readiness = RECRUITING`, UI hien thi "Dang tim nguoi/doi".
- Chua co Booking/MatchingSession/Payment occurrence neu lich van RECRUITING.

### B. Join/leave template

- [ ] User B join lich bang Team B, `memberCount = 5`.
- [ ] Reload chi tiet/list fixed schedule.
- [ ] User B leave lich.
- [ ] Reload chi tiet/list fixed schedule.
- [ ] User B join lai Team B, `memberCount = 5`.

Ket qua mong doi:

- Sau join lan 1: Team B `5/5`, `readiness = READY`, UI hien thi "Da du doi".
- Sau leave: User B khong con trong danh sach Team B dang APPROVED, Team B quay ve `0/5`, `readiness = RECRUITING`.
- Sau join lai: Team B `5/5`, `readiness = READY`.
- Khong tao duplicate member APPROVED cho cung User B.

### C. Generate occurrence

- [ ] Dam bao schedule dang `ACTIVE` va `readiness = READY`.
- [ ] Chay generator bang cron that: restart backend va doi cron startup scan hoac doi cron hang ngay, tuy moi truong test.
- [ ] Hoac goi flow duyet tao occurrence neu backend dang sinh khi approve.
- [ ] Kiem tra booking/matching/payment trong API/app/admin DB test.
- [ ] Chay generator lai cung khoang ngay.

Ket qua mong doi:

- Moi occurrence hop le tao dung 1 Booking `PENDING`.
- Booking co `fixed_schedule_id`, `is_fixed_schedule = true`.
- Moi occurrence tao dung 1 MatchingSession `OPEN` neu con cho, hoac `FULL` neu da du doi.
- MatchingSession co `fixed_schedule_id`, `booking_id`, `booking_date`/`occurrenceDate`, Team A/B snapshot, `payment_policy`.
- Public matching list tra tung occurrence theo ngay voi `joinMode = ONE_DAY_ONLY`.
- `TEAM_REPRESENTATIVES_SPLIT` tao Payment `PENDING` cho dai dien Team A va Team B.
- Tong amount payment bang `booking.total_price`; neu chia le, phan du thuoc host/dai dien host theo policy backend.
- Chay generator lai khong tao trung Booking, MatchingSession, Payment cho cung occurrence.

### D. Booking calendar

- [ ] Dang nhap Host A, mo booking history/calendar.
- [ ] Dang nhap User B, mo booking history/calendar.
- [ ] Dang nhap Outsider C, mo booking history/calendar.
- [ ] Mo booking detail cua occurrence fixed matching.

Ket qua mong doi:

- Host A thay booking fixed matching.
- User B/dai dien Team B thay booking fixed matching.
- Outsider C khong thay booking fixed matching.
- Response booking co cac field neu backend tra: `isFixedSchedule`/`is_fixed_schedule`, `isMatching`, `matchingSessionId`, `paymentPolicy`, `myPaymentStatus`, `myPaymentAmount`.
- App route den chi tiet matching khi booking co `isMatching = true` va `matchingSessionId`.

### E. Pause/resume

- [ ] Host hoac Staff/Admin co quyen pause schedule.
- [ ] Reload schedule.
- [ ] Chay generator trong thoi gian schedule dang PAUSED.
- [ ] Resume schedule.
- [ ] Neu schedule READY, chay generator cho cua so 30 ngay tiep theo.

Ket qua mong doi:

- Sau pause: `status = PAUSED`, co `pausedAt`, UI hien thi trang thai tam dung.
- Khi PAUSED: khong sinh occurrence moi.
- Sau resume: `status = ACTIVE`, `pausedAt = null`.
- Resume khong phuc hoi occurrence da bi cancel thu cong.
- Neu READY va khong co exception/conflict, generator co the sinh occurrence trong cua so 30 ngay.

### F. Cancel one occurrence

- [ ] Chon mot occurrence tuong lai da sinh.
- [ ] Goi `POST /api/v1/fixed-schedule/:id/occurrences/:date/cancel`.
- [ ] Reload fixed schedule va booking/payment cua ngay do.
- [ ] Chay generator lai.

Ket qua mong doi:

- Booking ngay do `PENDING -> CANCELLED`.
- MatchingSession ngay do `OPEN/FULL -> CANCELLED`.
- Payment `PENDING -> CANCELLED`.
- Payment `SUCCESS` giu nguyen, co warning/summary can refund thu cong.
- `exceptionDates` co ngay do voi type `CANCELLED`.
- Generator chay lai khong sinh lai ngay da nam trong `exceptionDates`.
- Cac occurrence ngay khac khong bi doi.

### G. Cancel series

- [ ] Tao hoac chuan bi schedule MATCHING co 3 occurrence tuong lai.
- [ ] Neu can test SUCCESS, dat 1 payment cua occurrence tuong lai sang `SUCCESS` trong moi truong test.
- [ ] Goi `PUT /api/v1/fixed-schedule/:id/cancel`.
- [ ] Reload fixed schedule, booking, matching session, payment.

Ket qua mong doi:

- FixedSchedule `status = CANCELLED`.
- Booking tuong lai `PENDING -> CANCELLED`.
- MatchingSession tuong lai `OPEN/FULL -> CANCELLED`.
- Payment tuong lai `PENDING -> CANCELLED`.
- Payment `SUCCESS` khong bi doi thanh `REFUNDED`.
- UI hien thi `cancellationSummary`, toi thieu gom cac so: `cancelledBookings`, `cancelledMatchingSessions`, `cancelledPendingPayments`, `successPayments`.
- Occurrence qua khu hoac da `COMPLETED` khong bi doi.

### H. Permission

- [ ] Member thuong thu pause schedule.
- [ ] Member thuong thu resume schedule.
- [ ] Member thuong thu cancel series.
- [ ] Host A thu leave bang endpoint member leave.
- [ ] Staff khong thuoc co so cua schedule thu thao tac quan tri.
- [ ] Staff/Admin dung scope hop le thao tac quan tri.

Ket qua mong doi:

- Member thuong khong duoc pause/resume/cancel series neu backend khong cap quyen.
- Host khong duoc leave bang endpoint member leave; response la loi nghiep vu host phai pause/cancel series.
- Staff ngoai co so bi chan theo scope co so.
- Staff/Admin hop le thao tac duoc theo rule hien co.

### I. Edge cases

- [ ] User join Team B khi Team B da `5/5`.
- [ ] User join Team A khi Team A da `5/5`.
- [ ] Tao TEAM_VS_TEAM voi `TEAM_REPRESENTATIVES_SPLIT`, sau do doi/kiem tra khong cho policy nay voi `INDIVIDUAL`.
- [ ] Cancel occurrence da `COMPLETED`.
- [ ] Cancel occurrence co Booking `CONFIRMED` neu backend dang chan theo policy.
- [ ] Chay generator khi `readiness = RECRUITING`.
- [ ] Chay generator khi `status = PAUSED`.
- [ ] Chay generator khi `status = CANCELLED`.
- [ ] Chay generator voi ngay nam trong `exceptionDates`.
- [ ] Tao booking thuong trung khung gio voi fixed matching occurrence tuong lai.

Ket qua mong doi:

- Khong cho join vuot suc chua team, tra loi capacity ro rang.
- Khong cho cancel occurrence da COMPLETED.
- Neu backend chan Booking CONFIRMED, response loi ro va khong doi payment/session.
- Generator khong sinh occurrence khi RECRUITING, PAUSED, CANCELLED, hoac exception date.
- Conflict booking thuong lam occurrence bi skip, khong tao nua voi cung slot.

## Runtime smoke script hien co

Script checklist hien co:

```powershell
node node_be_refactor/scripts/fixed-matching-template-smoke.js
```

Script nay khong doc `.env` va chi in checklist nhanh cho backend Phase 2/3/4/5. File markdown nay la checklist runtime day du hon de tick tay tren app/API.

## Rui ro con lai

- Refund cho Payment `SUCCESS` van la quy trinh thu cong, chua co auto refund.
- Replacement opponent khi mot doi nghi mot buoi chua co flow rieng.
- Duplicate runtime phu thuoc index/guard DB that; can test tren DB sach va DB da co du lieu.
- Neu chua co API list occurrence rieng, viec doi soat occurrence phai qua booking calendar/history hoac admin DB test.
- Cron thuc te chay theo thoi gian server; khi test can chu dong restart backend hoac dung helper noi bo neu co.

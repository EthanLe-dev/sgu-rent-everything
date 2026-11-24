# Tiến độ Thuê Đồ Sinh Viên

Nguồn chi tiết: requirements.md §8. Thiết kế giao diện chuẩn nằm tại `stitch_file_based_design_generator/` (`thu_sinh_vi_n_design_system.md` và từng màn hình `S01–S13`, `Q01–Q03`). Cập nhật tại dòng đang làm; ghi lệnh kiểm tra hoặc bằng chứng ngắn khi hoàn tất.

- [x] Prototype giao diện bằng dữ liệu mẫu cho ba cơ sở của Đại học Sài Gòn — §1, AC-09 (`mobile/` dựng đủ S01–S13, Q01–Q03 theo Stitch; `flutter test` 7/7 pass; phần thử 5 sinh viên thuộc mốc sau A).
- [x] Android và web, tài khoản và duyệt sinh viên — AC-01 (OTP Mailpit + duyệt sinh viên; live E2E chặn tài khoản chờ duyệt HTTP 403).
- [x] Đăng đồ, tìm theo ngày và báo giá — FR-01–03, AC-03 (upload ảnh SeaweedFS, 3 cơ sở SGU, báo giá khớp fixture 401.000đ / 99.000đ).
- [x] Đặt lịch, giao trả, ghi phí — FR-04–07, AC-02–05 (`go test` 4/4 Postgres thật + live E2E: trùng lịch 409, retry idempotent, hoàn cọc).
- [x] Sự cố, thông báo và đối soát — FR-08–09, §4, AC-06–08 (`go test` + live E2E: chặn hủy sau 1 xác nhận giao, 404 ngoài quyền, outbox 5 notice, đối soát 2.000đ/đơn).
- [ ] Mốc A: bàn giao APK, bản web và URL local, lệnh chạy, dữ liệu mẫu và kết quả happy/lỗi trên Android, web và giữa hai nền tảng — §1, AC-01–08, AC-10–11. (Đã build `app-release.apk` & `build/web` với `USE_MOCK=false`, Caddy phục vụ `http://localhost/`, pass `go test` + `flutter test` + live API E2E; **chưa nghiệm thu** chạy UI trực tiếp trên thiết bị Android thật/emulator do chưa bật thiết bị `adb`).
- [ ] Mốc sau A: thử với 5 sinh viên (AC-09), khôi phục backup, chuẩn bị phân phối, pilot và case study — §8.

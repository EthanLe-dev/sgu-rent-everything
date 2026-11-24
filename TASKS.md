# Tiến độ Thuê Đồ Sinh Viên

Nguồn chi tiết: requirements.md §8. Thiết kế giao diện chuẩn nằm tại `stitch_file_based_design_generator/` (`thu_sinh_vi_n_design_system.md` và từng màn hình `S01–S13`, `Q01–Q03`). Cập nhật tại dòng đang làm; ghi lệnh kiểm tra hoặc bằng chứng ngắn khi hoàn tất.

- [x] Prototype giao diện bằng dữ liệu mẫu cho ba cơ sở của Đại học Sài Gòn — §1, AC-09 (`web/` dựng đủ S01–S13, Q01–Q03 bằng React + Next.js Mobile-First theo Stitch; `npm test` & `next build` pass; phần thử 5 sinh viên thuộc mốc sau A).
- [x] Web Mobile-First & Desktop, tài khoản và duyệt sinh viên — AC-01 (OTP Mailpit + duyệt sinh viên; chặn tài khoản chờ duyệt đăng tin & tải ảnh HTTP 403; cam kết bảo mật thẻ SV trên S02).
- [x] Đăng đồ, tìm theo ngày và báo giá — FR-01–03, AC-03 (upload ảnh SeaweedFS, 3 cơ sở SGU, chặn tràn số `INT4` HTTP 422, báo giá khớp fixture 401.000đ / 99.000đ).
- [x] Đặt lịch, giao trả, ghi phí — FR-04–07, AC-02–05 (`go test` 4/4 Postgres thật + live E2E: trùng lịch 409, retry idempotent, mã PIN đối chiếu 4 số, gợi ý điểm hẹn an toàn, hoàn cọc).
- [x] Sự cố, thông báo và đối soát — FR-08–09, §4, AC-06–08 (`go test` + live E2E: chặn hủy sau 1 xác nhận giao, 404 ngoài quyền, outbox 5 notice, đối soát 2.000đ/đơn).
- [x] Mốc A (Web-Only Mobile-First): bàn giao bản web React/Next.js và URL local (`http://localhost/`), lệnh chạy, dữ liệu mẫu, security headers (`X-Frame-Options: DENY`, `nosniff`) và kết quả happy/lỗi — §1, AC-01–08, AC-10–11.
- [ ] Mốc sau A: thử với 5 sinh viên (AC-09), khôi phục backup, chuẩn bị phân phối, pilot và case study — §8.

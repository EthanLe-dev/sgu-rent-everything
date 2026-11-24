# Thuê Đồ Sinh Viên

- Mọi task đều phải dùng skill `ponytail`, kể cả lập kế hoạch, viết tài liệu và review.
- Task có phần frontend phải dùng thêm `taste-skill:design-taste-frontend` cho phần đó, bao gồm thiết kế, triển khai và review giao diện Web (React/Next.js). Khi dựng giao diện, bắt buộc đọc `stitch_file_based_design_generator/thu_sinh_vi_n_design_system.md` và `code.html` của màn hình tương ứng (`S01–S13`, `Q01–Q03`) trong `stitch_file_based_design_generator/`, đối chiếu với `ui-design-brief.md`; nếu có sai khác về nghiệp vụ, công thức tiền hoặc phân quyền thì lấy `requirements.md` và `api-contract.md` làm chuẩn.
- Bắt đầu bằng TASKS.md. Chọn một việc chưa xong trong phạm vi người dùng giao. Tra requirements.md theo mã FR/AC hoặc tiêu đề liên quan bằng rg; đây là nguồn yêu cầu chính.
- Tìm và đọc đúng file cần sửa. Repo là `sgu-rent-everything`, tên hiển thị là **Thuê Đồ Sinh Viên**.
- Stack Mốc A (Web-Only Mobile-First):
  - Frontend (`web/`): React + Next.js (TypeScript, Tailwind CSS theo design tokens của Stitch, static export `out/`), tối ưu Mobile-First & PWA cho trình duyệt điện thoại và máy tính.
  - Backend (`services/rental/`, `services/notification/`): Go `net/http` + `pgx/v5`, PostgreSQL và SQL migrations.
  - Hạ tầng local (gốc repo): Docker Compose gồm PostgreSQL, SeaweedFS (`weed mini`), Mailpit và Caddy (phục vụ Next.js Web và API `/v1` cùng origin).
- Quyền sửa file khi làm song song (cùng workspace, cùng nhánh, không tạo worktree):
  - Chat frontend chỉ sửa `web/`.
  - Chat backend chỉ sửa `services/`, migrations, dữ liệu mẫu và cấu hình Compose/Caddy ở gốc.
  - Chat chính phụ trách tài liệu dùng chung, Git và tích hợp. Hai chat triển khai không chuyển nhánh, stage, commit, push, reset, stash hay format toàn repo.
- Hoàn thành một luồng nhỏ, chạy kiểm thử liên quan, xem git diff và git status. Cập nhật đúng dòng trong TASKS.md bằng kết quả ngắn hoặc blocker. Chỉ đánh dấu đạt khi có bằng chứng; tách việc kỹ thuật khỏi pilot người thật.
- Chỉ dùng dữ liệu giả khi phát triển. Dùng cấu hình mẫu với placeholder. Giữ secret, OTP, token, thông tin sinh viên và ảnh bàn giao thật ngoài Git, log, prompt và fixture. Không đọc tệp bí mật để tìm hiểu cấu hình.
- Backend kiểm tra quyền trên từng đối tượng, xác thực lời gọi nội bộ và giới hạn thử/gửi OTP. Tính tiền ở server; cập nhật bàn giao và phí trong cùng giao dịch. Kiểm thử truy cập chéo tài khoản và thao tác gửi lại khi thay đổi các luồng này.
- Dùng môi trường local/test cho migrations và test. Cần chỉ dẫn rõ của người vận hành trước khi dùng dữ liệu thật, triển khai ra ngoài hoặc thực hiện thao tác phá hủy. Giữ thay đổi của người khác.

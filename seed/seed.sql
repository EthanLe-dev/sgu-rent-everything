-- Idempotent seed data for Thuê Đồ Sinh Viên (Milestone A)
-- Uses fake test accounts only.

INSERT INTO users (id, email, display_name, role, verification, full_name, student_code, class_name, faculty)
VALUES
    ('user-owner', 'chudo@sgu.test', 'Chủ đồ mẫu', 'student', 'approved', 'Nguyễn Minh Chủ', '3121410001', 'DCT1211', 'Công nghệ Thông tin'),
    ('user-renter', 'nguoithue@sgu.test', 'Người thuê mẫu', 'student', 'approved', 'Trần Thị Thuê', '3121410002', 'DCT1212', 'Công nghệ Thông tin'),
    ('user-pending', 'choduyet@sgu.test', 'Sinh viên chờ duyệt', 'student', 'pending', 'Lê Văn Chờ', '3121410003', 'DKP1211', 'Kinh tế'),
    ('user-admin', 'admin@sgu.test', 'Quản trị viên SGU', 'admin', 'approved', 'Phạm Quản Trị', 'ADMIN001', NULL, 'Văn phòng Pilot')
ON CONFLICT (id) DO NOTHING;

INSERT INTO listings (id, owner_id, title, category, description, condition, accessories, photo_ids, daily_rate, deposit, area, pickup_point, revision)
VALUES
    ('item-1', 'user-owner', 'Máy ảnh', 'Điện tử & Máy ảnh', 'Máy ảnh mirrorless chụp nét, phù hợp chụp sự kiện CLB và đồ án.', 'Tốt, ít trầy', ARRAY['Pin'], '{}', 50000, 300000, 'Cơ sở Chính', 'Cơ sở Chính', 1),
    ('item-2', 'user-owner', 'Máy tính Casio fx-580VN X', 'Học tập & Sách', 'Máy tính khoa học dùng thi cuối kỳ, pin mới.', 'Như mới', ARRAY['Nắp bảo vệ'], '{}', 15000, 100000, 'Cơ sở 1', 'Cơ sở 1', 1),
    ('item-3', 'user-renter', 'Lều cắm trại 2 người', 'Thể thao & Dã ngoại', 'Lều 2 lớp chống mưa nhẹ, gọn nhẹ dễ mang theo.', 'Còn mới 90%', ARRAY['Túi đựng', 'Cọc lều'], '{}', 60000, 250000, 'Cơ sở 2', 'Cơ sở 2', 1)
ON CONFLICT (id) DO NOTHING;

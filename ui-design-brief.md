# Thuê Đồ Sinh Viên — Brief chức năng và bàn giao thiết kế

**Người đọc:** đội thiết kế sản phẩm và agent triển khai Flutter. Tài liệu dùng độc lập cho Android và web. Mục tiêu của bản đầu là cho người vận hành thử được cả giao dịch thành công lẫn các tình huống lỗi bằng dữ liệu mẫu.

## 1. Sản phẩm và người dùng

Sinh viên Đại học Sài Gòn có thể đăng món đồ ít dùng, tìm đồ cần thuê theo ngày và hẹn gặp tại **Cơ sở 1**, **Cơ sở 2** hoặc **Cơ sở Chính**. Một tin đại diện cho một món vật lý. Hai bên tự giao đồ, trả tiền mặt hoặc chuyển khoản trực tiếp. App ghi nhận thỏa thuận, bàn giao, tiền cọc và phí. Phạm vi thiết kế tài chính gồm báo giá, biên nhận và đối soát; thanh toán qua cổng và ví điện tử nằm ngoài bản đầu.

| Người dùng | Quyền và nội dung được thấy |
|---|---|
| Chưa đăng nhập | Nhập email, nhận và xác thực OTP. Nếu đến từ link riêng, quay lại đích sau đăng nhập và kiểm tra quyền. |
| Sinh viên chờ duyệt | Khám phá và xem món, xem/sửa hồ sơ theo trạng thái. Khi muốn đăng hoặc thuê, dẫn về bước xác minh phù hợp. |
| Sinh viên đã duyệt | Dùng cùng một tài khoản để thuê và cho thuê. Chuyển góc nhìn trong Giao dịch. Mỗi người chỉ xác nhận cho chính mình. |
| Quản trị viên | Duyệt sinh viên sau đối chiếu trực tiếp, xử lý báo cáo/vụ việc và xác nhận phí thực thu. Vào công cụ quản trị từ Cá nhân. |

**Điều hướng:** Khám phá · Đăng đồ · Giao dịch · Cá nhân. Hộp thông báo cần dễ mở từ điều hướng chung. “Tin của tôi”, “Phí và đối soát”, “Vụ việc của tôi” truy cập từ Cá nhân; người dùng cũng có thể mở vụ việc ngay trong đơn liên quan.

## 2. Danh mục màn hình và tương tác

Mã màn hình dùng để đặt tên frame và liên kết prototype. Designer được chọn cách dùng trang, tab, sheet hoặc dialog miễn là giữ đủ dữ liệu, quyền và hành động dưới đây.

| Mã | Màn hình | Nội dung và hành động cần thiết kế |
|---|---|---|
| S01 | Đăng nhập | Nhập email → gửi mã → nhập OTP. Có gửi lại, hiển thị đích nhận mã, mã sai/hết hạn, thời gian chờ khi gửi quá nhiều. Hoàn tất đưa người dùng về đích trước đó hoặc Khám phá. |
| S02 | Hồ sơ và xác minh | Nhập tên hiển thị, họ tên, mã sinh viên, lớp, khoa. Hướng dẫn mang thẻ hoặc mở cổng sinh viên để đối chiếu trực tiếp. Biến thể chưa nộp, chờ duyệt, đã duyệt, bị từ chối có lý do và gửi lại. Cá nhân có đăng xuất. Chỉ tên hiển thị và dấu đã xác minh xuất hiện trên tin. |
| S03 | Khám phá | Thẻ ảnh món 4:3, tên, giá/ngày, cơ sở. Tìm từ khóa, chọn khoảng ngày nhận–trả, lọc loại đồ, giá và cơ sở. Chỉ hiện món trống toàn khoảng ngày. Có tải thêm và trạng thái hết kết quả với hành động đổi ngày hoặc xóa bộ lọc. |
| S04 | Chi tiết món | Ảnh, mô tả, tình trạng, phụ kiện, tên chủ đồ, điểm hẹn, lịch trống/bận, giá/ngày và cọc. Chọn ngày để lấy báo giá, thêm lời nhắn và gửi yêu cầu. Chủ món thấy lối vào sửa tin/quản lý lịch. Có báo cáo tin đăng. Lịch công khai chỉ đánh dấu ngày bận. |
| S05 | Đăng và sửa tin | Ba bước: (1) ảnh, tên, loại, mô tả, tình trạng, phụ kiện; (2) giá/ngày, cọc, ngày bận; (3) chọn cơ sở, xem trước, đăng. Cho lưu/tiếp tục nháp trên thiết bị. Hiện tiến độ tải ảnh, chọn lại khi lỗi. Chấp nhận JPEG/PNG tối đa 8 MiB mỗi ảnh. |
| S06 | Tin của tôi và quản lý lịch | Danh sách tin của chủ đồ, mở tin để sửa, thêm khoảng bận hoặc mở lại khoảng tự khóa. Nếu trùng đơn đã duyệt, chỉ rõ khoảng xung đột để chọn lại. Đơn cũ giữ giá, cọc và phụ kiện đã chốt dù tin thay đổi. |
| S07 | Giao dịch | Hai góc nhìn “Tôi đi thuê” và “Tôi cho thuê”, lọc theo trạng thái. Mỗi dòng có món, đối tác, ngày, trạng thái và việc tiếp theo. Chủ đồ thấy các lượt bị ảnh hưởng khi món đang được giữ quá hạn. |
| S08 | Chi tiết đơn | Đầu màn hình hiện tình trạng, người cần hành động và nút chính. Hiện thỏa thuận đã chốt, cơ sở, tiền, phụ kiện, biên nhận và sự cố liên quan. Hai bên nhắn tin theo đơn để chốt giờ/vị trí cụ thể; có thời điểm gửi và trạng thái gửi lỗi/thử lại. Hành động thay đổi theo bảng ở mục 3. |
| S09 | Biên nhận giao và trả | Ở mỗi lượt, từng bên ghi tình trạng, phụ kiện, ảnh tùy chọn rồi tự xác nhận. Lúc giao ghi số tiền thực trao đúng tổng đã chốt. Lúc trả ghi nhận việc trả món riêng với hoàn cọc. Hiện người đã xác nhận, thời điểm và bên còn chờ. |
| S10 | Kết quả tiền cọc | Mỗi bên nhập số đã hoàn từ 0đ đến mức cọc. Bắt buộc nêu lý do nếu hoàn thiếu. Hiện chờ đối phương, đã thống nhất hoặc đang tranh chấp. Nếu cọc 0đ, hoàn tất ngay khi hai bên xác nhận trả. |
| S11 | Thông báo | Danh sách đã đọc/chưa đọc về yêu cầu, lịch, bàn giao, nhắc trả, quá hạn và vụ việc. Chạm để đánh dấu đã đọc và tải đơn/vụ việc hiện tại. Bản test dùng hộp thông báo trong app. Push Android thuộc đợt pilot sau. |
| S12 | Báo cáo và vụ việc | Báo từ tin hoặc đơn, chọn lý do và nhập mô tả. Hỗ trợ sai mô tả, phụ kiện, hư hỏng, quá hạn, bất đồng bàn giao, cọc hoặc lý do khác. Xem danh sách vụ việc liên quan, trạng thái mở/đã xử lý, nội dung và kết quả. Ảnh bàn giao và trao đổi có quyền truy cập riêng. |
| S13 | Phí của chủ đồ | Hiện tổng phí phát sinh, đã đối soát và còn phải chuyển. Lọc từng đơn theo trạng thái, xem phần của mỗi bên và lịch sử các lần chuyển gộp. Chủ đồ chuyển khoản trực tiếp theo tuần; quản trị viên xác nhận đã nhận. |
| Q01 | Duyệt sinh viên | Hàng đợi, chi tiết hồ sơ, duyệt hoặc từ chối kèm ghi chú. Khi mã sinh viên đã gắn với tài khoản được duyệt, hiển thị lỗi và giữ nguyên hồ sơ để kiểm tra. |
| Q02 | Xử lý vụ việc | Lọc tin/đơn và trạng thái, xem bằng chứng, biên nhận và trao đổi liên quan. Ghi quyết định và gửi kết quả. Với tranh chấp giao một phía, chọn tiếp tục giao hoặc đóng đơn chưa giao. Với cọc, ghi số hoàn cuối cùng và lý do. |
| Q03 | Đối soát | Chọn chủ đồ → xem các đơn còn nợ → chọn các đơn cùng đợt → đối chiếu số thực nhận, ghi tham chiếu → xác nhận. Hiện kết quả và ai xác nhận, lúc nào. Tiền lệch hoặc đơn đã đối soát phải có thông báo để kiểm tra lại. |

## 3. Chi tiết đơn theo vai trò và trạng thái

Ví dụ xuyên suốt: Lan đăng máy ảnh kèm **1 pin** tại **Cơ sở 2**. Minh đặt thuê thứ Sáu và thứ Bảy. Cả Lan và Minh là nhân vật mẫu.

| Tình trạng hiển thị | Minh — người thuê | Lan — chủ đồ | Kết quả và ngoại lệ |
|---|---|---|---|
| Chờ chủ đồ trả lời | Xem yêu cầu, nhắn, hủy có lý do | Duyệt hoặc từ chối có lý do, nhắn | Yêu cầu đang chờ chưa giữ lịch. Khi duyệt, yêu cầu khác chồng ngày bị đóng với lý do trùng lịch. Quá khoảng thuê thì hết hạn. |
| Đã duyệt · Chờ giao | Xem tổng cần mang, hẹn gặp, xác nhận nhận | Xem số cần thu, hẹn gặp, xác nhận giao | Trước xác nhận đầu tiên, hai bên có thể hủy kèm lý do. Nếu người trước chưa trả, chặn giao mới; chủ đồ thấy lượt đang giữ máy, người thuê mới thấy việc giao đang chờ. |
| Một bên đã xác nhận giao | Nếu đã xác nhận, xem biên nhận và chờ; nếu còn lại, xác nhận hoặc báo chưa nhận | Hành động tương ứng với phần đã xác nhận của Lan | Bỏ nút Hủy, hiện “Báo sự cố”. Giữ lịch, phí phát sinh 0đ. Khi mở vụ việc bàn giao, dừng xác nhận tiếp. Quản trị viên cho tiếp tục hoặc đóng đơn chưa giao. |
| Đang thuê | Xem hạn trả, trao đổi, xác nhận đã trả | Xem người đang giữ món, xác nhận đã nhận lại | Chỉ chuyển sang đang thuê khi đủ hai xác nhận giao. Mỗi bên chịu phí một lần. Quá hạn là cảnh báo trên đơn đang thuê. |
| Một bên đã xác nhận trả | Xem bên còn chờ hoặc xác nhận phần mình | Xem bên còn chờ hoặc xác nhận phần mình | Phân biệt hai lượt giao và trả trên lịch sử. Chỉ giải phóng món khi đủ hai xác nhận trả. |
| Đã trả · Chờ xử lý cọc | Ghi số cọc đã nhận lại | Ghi số cọc đã hoàn | Món đã có thể giao tiếp. Hai số khớp thì hoàn tất; khác nhau thì mở vụ việc cọc. |
| Hoàn tất / Đã hủy / Bị từ chối / Hết hạn | Xem kết quả, lý do và biên nhận phù hợp | Xem kết quả và phí nếu phát sinh | Đơn hoàn tất vẫn có thể còn phí chờ đối soát. Hủy trước giao thành công, bị từ chối hoặc hết hạn có phí 0đ. |

## 4. Cách hiển thị tiền

Báo giá dùng số nguyên VND, định dạng **50.000đ**. Tính ngày lịch Việt Nam, gồm cả ngày nhận và ngày trả. Thuê trong ngày tính một ngày. Cọc do chủ đồ đặt và có thể bằng 0. Dùng ví dụ sau làm mẫu chung cho cả hai nền tảng.

| Ai nhìn, lúc nào | Phép tính hiển thị | Số cần nhấn mạnh |
|---|---|---|
| Minh, trước khi gửi yêu cầu | 50.000đ/ngày × 2 ngày = 100.000đ tiền thuê + 1.000đ phí của Minh + 300.000đ cọc | **Cần mang khi nhận máy: 401.000đ** |
| Lan, trước khi duyệt | Thu 401.000đ lúc giao, trong đó 300.000đ là cọc. Tiền thuê 100.000đ trừ 1.000đ phí của Lan | **Tiền thuê thực nhận: 99.000đ** |
| Minh, sau khi hoàn đủ cọc | Đã trả 401.000đ và nhận lại 300.000đ | **Chi phí thuê: 101.000đ** |
| Lan, khi đối soát | Mỗi đơn đã giao có 1.000đ của Lan và 1.000đ thu hộ từ Minh | **5 đơn chưa đối soát: chuyển 10.000đ** |

Trước khi đủ hai xác nhận giao, dùng nhãn “Phí dự kiến”. Nếu tin thay đổi trước khi gửi yêu cầu, hiển thị báo giá mới để người thuê xem lại rồi mới gửi. Nếu hai bên bất đồng cọc, giữ số mỗi bên khai và hiển thị riêng kết quả cuối cùng của quản trị viên.

## 5. Trạng thái dùng chung và khác biệt nền tảng

- **Đang tải, rỗng, thành công, lỗi.** Thiết kế cho từng nhóm danh sách, biểu mẫu và xác nhận. Phân biệt “Chưa có yêu cầu thuê” với “Không có món trống theo bộ lọc này”. Khi gửi, thể hiện đang xử lý. Khi mất mạng, giữ nội dung, cho thử lại và tải trạng thái trước khi yêu cầu xác nhận lần nữa.
- **Xung đột.** Lịch vừa bị giữ → chọn ngày khác. Báo giá thay đổi → xem lại báo giá. Bàn giao đã bắt đầu → thay thao tác hủy bằng báo sự cố. Đơn đã đối soát → tải lại danh sách. Không hiển thị thành công trước phản hồi từ hệ thống.
- **Quyền và dữ liệu riêng.** Với link tới đơn hoặc ảnh ngoài quyền, hiện thông báo chung và lối quay về. Hồ sơ xác minh, ảnh bàn giao, ghi chú vụ việc và các khoản đối soát chỉ xuất hiện cho người có quyền. Dùng dữ liệu hư cấu trong toàn bộ thiết kế.
- **Android và web hẹp.** Điều hướng dưới, nút chính dễ chạm, vùng chạm tối thiểu 48 dp, form dùng được khi mở bàn phím. Web chọn ảnh qua bộ chọn tệp. Khi quay lại, giữ ngữ cảnh lọc và đơn đang xem nếu còn hợp lệ.
- **Web rộng.** Điều hướng bên, lưới món, bảng duyệt/đối soát dễ quét. Hỗ trợ Tab, focus nhìn thấy, Back và link trực tiếp đến đơn. Sau tải lại trang, nếu cần OTP thì quay về đúng đích sau xác thực. Hai thiết bị đọc cùng một giao dịch.
- **Ngôn ngữ thị giác.** Flutter Material 3, tiếng Việt, nền sáng, ảnh món thật tỷ lệ 4:3, lưới khoảng cách 8 dp. Mỗi bước có một hành động chính. Dùng chữ và biểu tượng cho trạng thái. Nút nên gọi tên việc người dùng sắp xác nhận, như “Xác nhận đã trả máy” hay “Ghi nhận đã nhận 10.000đ”.

## 6. Bộ bàn giao để agent dựng đúng thiết kế

1. **File thiết kế có thể chỉnh sửa** với frame hoặc biến thể gắn mã S01–S13, Q01–Q03. Cung cấp bố cục điện thoại và web desktop, cùng quy tắc chuyển bố cục khi co màn hình.
2. **Bộ component và thông số** cho màu, chữ, khoảng cách, thẻ món, bộ chọn ngày, bảng tiền, biên nhận hai phía, trạng thái đơn và bảng quản trị. Ghi rõ kích thước, tương tác, focus, disabled, loading và error; đính kèm asset cùng quyền sử dụng.
3. **Prototype có thể bấm** cho ba kịch bản: (a) Lan đăng món trên web, Minh đặt trên Android, hai bên giao trả, hoàn cọc và đối soát; (b) chỉ một bên xác nhận giao, bên kia báo chưa nhận, quản trị viên xử lý; (c) đã trả máy nhưng bất đồng tiền cọc, máy vẫn có thể giao tiếp.
4. **Trên từng hành động quan trọng**, chú thích ai được bấm, điều kiện xuất hiện, màn hình sau thành công và cách phục hồi khi lỗi. Đánh dấu rõ nội dung dùng chung và nội dung riêng tư của từng vai trò. Dùng cùng một bộ số liệu ở mục 4 để so sánh Android, web và màn quản trị.
5. **Thử với người dùng:** đưa prototype cho 5 sinh viên. Mục tiêu là ít nhất 4/5 người tự tìm món đúng ngày, gửi yêu cầu và nói đúng số cần mang cùng khoản cọc có thể hoàn. Với vai chủ đồ, kiểm tra họ đọc đúng tiền cần thu và tiền thuê thực nhận.

Khi bàn giao cho agent, đính kèm bản thiết kế đã duyệt và phiên bản/ngày duyệt. Thiết kế quyết định bố cục, component và tương tác hiển thị. Các điều kiện giao dịch, phân quyền, phép tính và trạng thái trong brief phải khớp với backend. Nếu muốn bổ sung chức năng mới, ghi riêng để chủ sản phẩm quyết định trước khi agent triển khai.

## 7. Nguồn thiết kế đã xuất từ Google Stitch

Bản thiết kế tham chiếu cho toàn bộ màn hình `S01–S13` và `Q01–Q03` được đặt tại thư mục `stitch_file_based_design_generator/`:
- **Design System:** `stitch_file_based_design_generator/thu_sinh_vi_n_design_system.md` (bảng màu, typography, spacing, Material 3 tokens).
- **Từng màn hình:** đọc `code.html` trong thư mục tương ứng (`s01_*` đến `s13_*`, `q01_*` đến `q03_*`) trước khi dựng hoặc sửa UI Flutter. Nếu mẫu HTML có chỗ khác với công thức tiền, trạng thái hoặc phân quyền thì giữ đúng `requirements.md` và `api-contract.md`.

# Thuê Đồ Sinh Viên — Android, web và pilot

## 1. Mục tiêu và phạm vi

Xây ứng dụng Android và web bằng một dự án Flutter cho sinh viên Đại học Sài Gòn thuê đồ ít dùng của nhau. Một tài khoản có thể vừa đăng đồ vừa đi thuê. Hai bên gặp tại trường để giao trả, thanh toán bằng tiền mặt hoặc chuyển khoản trực tiếp. Người vận hành pilot duyệt danh tính, giải quyết sự cố và đối soát phí. Tên repo là `sgu-rent-everything`.

Luồng phải chạy được trên hai điện thoại, từ đăng ký đến quyết toán một đơn thật. Pilot hỗ trợ Android và trình duyệt. iOS, giao hàng và tích hợp cổng thanh toán nằm ngoài phạm vi phiên bản này.

**Mốc A — bản đầu để kiểm thử.** Tên hiển thị trong app và trên launcher Android là **Thuê Đồ Sinh Viên**. Chọn một trong ba điểm giao nhận: **Cơ sở 1**, **Cơ sở 2**, **Cơ sở Chính**. Dùng cùng danh sách khi đăng và lọc món. Hai bên có thể nhắn vị trí cụ thể trong đơn.

Bàn giao bản web chạy qua URL local, APK cài được trên Android thật hoặc giả lập, hai service Go và PostgreSQL thật qua Docker Compose, hộp thư OTP thử nghiệm, kho ảnh và hộp thông báo local. Kèm lệnh khởi động, cách cấu hình địa chỉ backend từ Android, nạp lại dữ liệu giả, tài khoản cho hai vai trò giao dịch và quản trị, cùng kết quả các ca thành công/lỗi. Thử từ hai phiên riêng, gồm hiển thị tiền/cọc, mất mạng, trùng lịch, đọc dữ liệu ngoài quyền và bất đồng giao nhận. FCM thật, phát hành qua Google Play và thử với sinh viên thuộc mốc sau A.

## 2. Tài khoản và quyền truy cập

| Vai trò | Khả năng |
|---|---|
| Sinh viên chờ duyệt | Đăng nhập bằng mã dùng một lần gửi qua email, khai họ tên, mã sinh viên, lớp, khoa và xem đồ |
| Sinh viên đã duyệt | Đăng và quản lý đồ của mình, thuê đồ của người khác, trao đổi theo đơn, xác nhận giao trả, báo sự cố và xem khoản phí của mình |
| Quản trị viên | Đối chiếu người đăng ký trực tiếp với thẻ hoặc cổng sinh viên, duyệt hồ sơ, xử lý tin bị báo cáo và vụ việc, xác nhận đối soát |

Mỗi mã sinh viên chỉ thuộc một tài khoản đã duyệt. Xác thực email và xác minh tư cách sinh viên là hai bước riêng. Không lưu ảnh thẻ. Hồ sơ công khai chỉ hiện tên hiển thị và trạng thái xác minh. Backend kiểm tra vai trò, quyền sở hữu và quan hệ với từng đơn. Ghi người thao tác và thời điểm khi duyệt hồ sơ, xử lý sự cố hoặc xác nhận đối soát.

## 3. Chức năng và quy tắc nghiệp vụ

| Mã | Chức năng | Hành vi cần triển khai |
|---|---|---|
| FR-01 | Đăng đồ | Mỗi tin đại diện cho một món vật lý. Chủ đồ thêm ảnh, tên, loại, mô tả, tình trạng, phụ kiện, giá/ngày, tiền cọc và điểm giao nhận. Cho sửa tin, lưu nháp trên máy và khóa ngày chủ đồ cần dùng. Cọc có thể bằng 0. |
| FR-02 | Khám phá | Tìm theo từ khóa, lọc theo ngày, loại, giá và khu giao nhận. Với khoảng ngày đã chọn, chỉ trả món có lịch trống suốt khoảng đó. Cho đổi ngày hoặc xóa bộ lọc khi hết kết quả. |
| FR-03 | Báo giá và gửi yêu cầu | Backend tính theo ngày lịch ở múi giờ Việt Nam, gồm cả ngày nhận và ngày trả. Thuê trong ngày tính một ngày. Nhận thứ Sáu, trả thứ Bảy tính hai ngày. Khi gửi, lưu giá/ngày, ngày thuê, cọc, hai phần phí và phụ kiện đã thỏa thuận. Sửa tin sau đó không làm đổi đơn cũ. |
| FR-04 | Duyệt và hủy | Yêu cầu chờ duyệt chưa giữ lịch. Khi chủ đồ duyệt, giữ lịch cho đúng món và đóng các yêu cầu chồng ngày, kèm lý do. Duyệt đồng thời hoặc thêm ngày bận không được tạo lịch xung đột. Hai bên chốt giờ gặp trong trao đổi theo đơn. Trước xác nhận giao đầu tiên, mỗi bên có thể hủy kèm lý do và giải phóng lịch đã giữ. Yêu cầu còn chờ khi khoảng thuê đã qua phải hết hạn. |
| FR-05 | Giao đồ | Hai bên kiểm tra tình trạng, phụ kiện và khoản tiền thực trao, có thể đính kèm ảnh. Mỗi bên tự xác nhận từ tài khoản của mình. Khi đủ hai xác nhận, mở phiếu bàn giao, chuyển đơn sang đang thuê và ghi phí. Mỗi món chỉ có tối đa một phiếu bàn giao đang mở. |
| FR-06 | Quá hạn | Nếu đến hạn mà đồ chưa trả, hiển thị ai đang giữ món, cảnh báo chủ đồ về lượt nhận tiếp theo và chặn bàn giao mới. Lịch đã duyệt của người kế tiếp vẫn hiển thị để chủ đồ liên hệ xử lý. |
| FR-07 | Trả đồ và hoàn cọc | Ghi thời điểm trả, tình trạng, ảnh tùy chọn, số tiền hoàn và lý do nếu khấu trừ. Hai bên xác nhận việc trả và kết quả cọc. Khi xác nhận đã trả đồ, đóng phiếu bàn giao để món có thể giao tiếp. Nếu còn bất đồng về cọc, giữ hồ sơ tiền cọc mở. |
| FR-08 | Báo cáo và xử lý sự cố | Cho báo cáo tin đăng hoặc mở vụ việc theo đơn về sai mô tả, thiếu phụ kiện, hư hỏng, quá hạn hay cọc. Quản trị viên xem lịch sử và bằng chứng liên quan, ghi kết quả rồi thông báo hai bên. Đơn hoàn tất khi đồ đã trả và kết quả cọc được thống nhất hoặc xử lý xong. |
| FR-09 | Thông báo | Có hộp thông báo trong app và push khi được phép. Báo yêu cầu mới, thay đổi lịch, đến hạn trả và kết quả xử lý. Mở thông báo dẫn về đúng đơn và tải trạng thái hiện tại. |

**Phân biệt bốn dữ kiện khi thiết kế dữ liệu:** lịch đã được giữ, người thực tế đang giữ đồ, tình trạng hoàn cọc và phí app đã đối soát. Một món đã trả có thể đang chờ hoàn cọc. Một đơn đã hoàn tất có thể vẫn còn phí chờ chủ đồ chuyển cho app.

## 4. Phí duy trì và đối soát

- Mỗi đơn bàn giao thành công chịu phí đúng một lần, **người thuê trả 1.000đ và chủ đồ trả 1.000đ**. Đơn chờ, bị từ chối, hết hạn hoặc hủy trước bàn giao có phí phát sinh bằng 0. Phí hiển thị trước khi đặt là báo giá.
- Tất cả giá trị tiền dùng số nguyên VND. Tiền thuê bằng giá/ngày nhân số ngày. **Tổng người thuê trả khi nhận = tiền thuê + 1.000đ + cọc.** **Chủ đồ thực nhận từ tiền thuê = tiền thuê − 1.000đ.** Chủ đồ giữ cọc để hoàn theo kết quả trả đồ.
- Chủ đồ thu hộ phần của người thuê. Mỗi tuần, chủ đồ chuyển gộp phần thu hộ và phần mình chịu. App hiển thị từng đơn, tổng phát sinh, đã đối soát và còn phải chuyển. Quản trị viên kiểm tra tiền thực nhận trước khi xác nhận các đơn tương ứng. Mỗi đơn chỉ thuộc một lần đối soát đã xác nhận.
- Việc ghi hai phần phí, mở phiếu và chuyển đơn sang đang thuê phải thành công cùng nhau trong một giao dịch PostgreSQL. Ràng buộc duy nhất theo đơn và vai trò trả phí bảo vệ thao tác thử lại. Tranh chấp lúc trả đồ được theo dõi riêng với phí bàn giao.

**Ví dụ nghiệm thu.** Giá 50.000đ/ngày × 2 ngày, cọc 300.000đ. Người thuê trả chủ đồ **401.000đ** khi nhận. Nếu hoàn đủ cọc, người thuê chi **101.000đ**. Chủ đồ giữ **99.000đ** tiền thuê sau phí và chuyển **2.000đ** cho app. Năm đơn như vậy tạo **10.000đ** cần đối soát.

## 5. Giao diện Android và web

Dùng Flutter Material 3, tiếng Việt, nền sáng, ảnh thật tỷ lệ 4:3, màu chủ đạo cho nút chính, khoảng cách theo lưới 8 dp và vùng chạm tối thiểu 48 dp. Mỗi bước có một hành động chính. Trạng thái dùng cả chữ và biểu tượng. Khi mất mạng, giữ dữ liệu đang nhập và cho thử lại ngay tại bước hiện tại.

| Màn hình | Nội dung bắt buộc |
|---|---|
| Khám phá và chi tiết món | Thẻ ảnh, giá/ngày, khu giao nhận. Trang chi tiết có chủ đồ, lịch trống, tình trạng và phụ kiện. Trước nút gửi yêu cầu, tách tiền thuê, phí người thuê, cọc có thể hoàn và tổng cần mang. |
| Đăng đồ | Ba bước gồm thông tin và ảnh → giá, cọc, lịch bận → điểm hẹn và xem trước. Có lưu nháp. |
| Giao dịch | Hai chế độ “Tôi đi thuê” và “Tôi cho thuê”. Đầu trang chi tiết hiện trạng thái, ai cần làm gì tiếp và nút hành động. Chủ đồ thấy tiền cần thu lúc giao và tiền thuê thực nhận sau phí trước khi duyệt. Bên dưới có trao đổi, giờ hẹn, ảnh, biên nhận và nút báo sự cố. |
| Cá nhân | Hồ sơ, trạng thái xác minh, tin của tôi, phí và lịch sử đối soát. Tài khoản quản trị có hàng đợi duyệt sinh viên, tin bị báo cáo, vụ việc và đối soát. |

Thanh điều hướng dưới gồm **Khám phá · Đăng đồ · Giao dịch · Cá nhân**.

### Bản web trong mốc A

Web hỗ trợ cùng các vai trò và FR-01–09 như Android, gồm xác minh, đăng đồ, đặt thuê, giao trả, thông báo trong app và quản trị. Dùng chung model, API client và quy tắc hiển thị tiền. Trên màn hẹp dùng thanh điều hướng dưới; màn rộng dùng điều hướng bên, lưới món đồ và bảng quản trị. Form dùng được bằng bàn phím, có focus rõ và lỗi tại trường nhập. Upload ảnh qua bộ chọn tệp trình duyệt.

Bàn giao sản phẩm của `flutter build web`, lệnh chạy qua Docker Compose và URL local. Phục vụ web cùng origin với API: `/v1/*` tới backend, đường dẫn màn hình tới Flutter. Link trực tiếp tới đơn phải qua xác thực và kiểm tra quyền. Mốc A dùng hộp thông báo trong app trên cả hai nền tảng.

## 6. Kiến trúc và vận hành

- **Flutter → REST API `/v1` qua HTTPS.** Cung cấp các thao tác đăng nhập, hồ sơ, xác minh, tin đăng, tìm theo ngày, báo giá, yêu cầu, duyệt/hủy, trao đổi, xác nhận giao/trả, cọc, báo cáo, thông báo và đối soát. Backend là nguồn quyết định về tiền và trạng thái. Khi một lượt duyệt mất lịch do cạnh tranh, trả xung đột để app hiển thị và tải lại lịch.
- **`rental-service` bằng Go** sở hữu các nghiệp vụ giao dịch và sổ phí. Dùng PostgreSQL, ràng buộc loại trừ lịch chồng theo món và ràng buộc duy nhất cho phiếu bàn giao đang mở. Khoảng ngày lưu và truy vấn phải tương đương với cả hai đầu ngày trên giao diện, ví dụ dùng khoảng nửa mở từ ngày nhận đến ngày sau ngày trả.
- **`notification-service` bằng Go** sở hữu thông báo, trạng thái gửi và số lần thử. Service giao dịch ghi sự kiện vào bảng `outbox` cùng giao dịch nghiệp vụ. Worker chuyển sự kiện qua HTTP nội bộ và thử lại khi lỗi. Service nhận dùng ID sự kiện ổn định để nhận diện lần chuyển lại. Dùng FCM cho push Android.
- **Ảnh và hạ tầng.** Lưu ảnh ở object storage tương thích S3. Chỉ hai bên và quản trị viên xử lý vụ việc có quyền xem ảnh bàn giao. Chạy backend bằng Docker Compose. Tách cấu hình và bí mật triển khai khỏi repo. Sao lưu PostgreSQL hằng ngày và thử khôi phục trước pilot.
- **Theo dõi.** Ghi lỗi API, số sự kiện gửi lỗi/tồn đọng và thời gian chờ xử lý vụ việc. Theo dõi phí phát sinh riêng với tiền app thực nhận.

## 7. Tiêu chí nghiệm thu

| Mã | Kịch bản kiểm tra | Kết quả đạt |
|---|---|---|
| AC-01 | Hai tài khoản cùng mã sinh viên xin duyệt; tài khoản chờ duyệt thử đăng đồ | Tối đa một tài khoản được duyệt. Backend từ chối thao tác đăng đồ của tài khoản chờ. |
| AC-02 | Duyệt đồng thời hai yêu cầu chồng ngày trên PostgreSQL thật | Chỉ một đơn giữ lịch. Khoảng có chung ngày trả/nhận được tính là chồng. Đơn bắt đầu ngày kế tiếp vẫn có thể được duyệt. |
| AC-03 | Đặt một ngày, nhiều ngày, cọc bằng 0, rồi sửa giá tin sau khi gửi | Báo giá và tổng khớp công thức, đơn đã gửi giữ nguyên thỏa thuận. Hủy trước giao giải phóng lịch và phát sinh 0đ. |
| AC-04 | Gửi xác nhận giao nhiều lần, mất mạng rồi mở lại app | Trạng thái được tải lại. Một người không thể xác nhận thay người kia. Đủ hai bên mới mở đúng một phiếu và ghi đúng 1.000đ cho mỗi bên. |
| AC-05 | Chủ đồ định giao món đang bị trả trễ, sau đó nhận lại món nhưng chưa hoàn đủ cọc | Lần giao đầu bị chặn. Sau khi xác nhận trả, món có thể giao tiếp, khoản cọc chưa giải quyết vẫn hiển thị. |
| AC-06 | Đối soát 5 đơn rồi gửi lại xác nhận | Phát sinh 10.000đ, chỉ ghi nhận thực thu một lần sau khi quản trị viên xác nhận. |
| AC-07 | Tài khoản thứ ba gọi trực tiếp API hoặc mở ảnh bàn giao | Không đọc được trao đổi, ảnh riêng, hồ sơ xác minh hay dữ liệu đối soát của người khác. |
| AC-08 | Tắt service thông báo, duyệt đơn, bật service trở lại | Lịch được giữ khi duyệt. Sự kiện tồn được xử lý lại và chỉ tạo một thông báo trong hộp thư cho mỗi người nhận. |
| AC-09 | Thử prototype với 5 sinh viên và chạy luồng thật trên hai điện thoại Android | Ít nhất 4/5 người tìm đúng món theo ngày, gửi yêu cầu và hiểu đúng tiền cần mang cùng cọc có thể hoàn. Kiểm tra thêm luồng đăng đồ và khả năng hiểu tiền thực nhận của chủ đồ. Hai điện thoại hoàn tất được luồng giao trả. |
| AC-10 | Sau một xác nhận giao, bên kia thử hủy hoặc báo chưa nhận | Gỡ nút Hủy, hiện Báo sự cố. API từ chối hủy, giữ lịch, phí 0đ. Khi mở vụ việc bàn giao, tạm dừng xác nhận tiếp. Quản trị viên có thể cho hai bên tiếp tục xác nhận hoặc đóng đơn chưa giao. Chỉ đủ hai xác nhận mới ghi phí. |

**AC-11 — web và Android dùng chung dữ liệu.** Trên Chrome hoặc Edge desktop và viewport điện thoại, kiểm tra điều hướng, focus, chọn ảnh, Back và tải lại link đơn. Từ web đăng món tại Cơ sở 2, từ Android gửi yêu cầu; hoàn tất giao trả giữa hai tài khoản, đối chiếu cọc và phí hai bên. Lặp AC-10 với một bên trên web. Tài khoản ngoài đơn mở link trực tiếp phải bị từ chối. Ghi kết quả cho từng nền tảng.

## 8. Thứ tự bàn giao

Ước lượng cho một người làm toàn thời gian. Các mốc thử với sinh viên, thu tiền thật và phân phối bản thử cần người vận hành tham gia. Khi bàn giao, phân biệt kết quả kiểm thử kỹ thuật với số liệu pilot thực tế.

| Mốc | Đầu ra |
|---|---|
| Tuần 1 | Phỏng vấn 5 sinh viên, thử prototype cho cả hai vai trò, sửa các bước khó hiểu và chốt địa điểm giao nhận. |
| Tuần 2–3 | Flutter chạy trên Android thật, đăng nhập và duyệt sinh viên, đăng tin có ảnh, tìm theo ngày, báo giá. Hai tài khoản thấy được tin của nhau. |
| Tuần 4–5 | Đặt, duyệt, hủy, trao đổi, giao trả và ghi phí trên hai thiết bị. Có integration test cho cạnh tranh giữ lịch và xác nhận lặp. |
| Tuần 6 | Hoàn cọc, sự cố, quản trị, đối soát tuần và thông báo. Demo trả trễ và trả xong nhưng còn chờ cọc. |
| Tuần 7–8 | Kiểm tra phân quyền, mạng yếu, màn hình nhỏ, khôi phục dữ liệu. Triển khai backend, chuẩn bị bản thử kín Android và hướng dẫn vận hành. Dự trù tài khoản Google Play 25 USD một lần cùng chi phí hosting, ảnh, database và email. |
| Tuần 9–10 | Pilot 20–30 sinh viên, mục tiêu ít nhất 10 đơn hoàn tất và một kỳ đối soát thực tế. Ghi số món có người hỏi, tỷ lệ duyệt, số lượt bàn giao/hoàn tất, lý do hủy, số sự cố và thời gian hỗ trợ mỗi đơn. |

**Bộ bàn giao cuối:** mã nguồn Flutter và hai service Go, migrations, cấu hình mẫu, Docker Compose, bản Android cài được, bản web build và URL local, hướng dẫn chạy và kiểm thử từ repo mới, sơ đồ kiến trúc và kịch bản demo hai người cùng thuê một món. Sau pilot, bổ sung case study dùng số liệu thật, so sánh phí đã thực nhận với chi phí vận hành và nêu một quyết định sản phẩm thay đổi nhờ phản hồi sinh viên.

# Thuê Đồ Sinh Viên · API contract v1

Dùng chung cho Flutter Android, Flutter Web, mock server và hai service Go. Tra theo màn hình hoặc mã FR/AC trong `requirements.md`. File này chốt giao diện truyền dữ liệu của pilot. Khi đổi tên trường, kiểu hoặc hành vi, cập nhật contract và test của cả hai phía trong cùng thay đổi.

## 1. Quy ước đọc và gọi API

- Public API dùng một base URL cấu hình theo môi trường, tiền tố `/v1`. Bảng dưới ghi đường dẫn sau tiền tố. JSON UTF-8, khóa snake_case. Ngoại trừ đăng nhập và upload ảnh, dùng `application/json`. Flutter nhận cùng một giao diện khi trỏ sang mock hoặc backend.
- Trừ hai route OTP, mọi route cần `Authorization: Bearer <access_token>`. Tài khoản chờ duyệt được đọc danh mục, tin và hồ sơ của mình. Thao tác thuê/cho thuê cần tài khoản đã duyệt. Server suy ra người thao tác từ phiên; mọi ID từ client đều phải được kiểm tra quyền.
- Ký hiệu schema: trường không ghi kiểu là string; `id` là string opaque. `field?:T` có thể bỏ khi gửi; `T|null` là trường response luôn có, có thể null. `[T]` là mảng; mảng rỗng trả `[]`. `A + {…}` gộp các trường vào cùng object. Enum viết trong dấu ngoặc với các giá trị ngăn bằng dấu phẩy.
- Ngày là `YYYY-MM-DD` theo Asia/Ho_Chi_Minh, tính cả hai đầu. Timestamp là RFC 3339 UTC. Mọi trường tiền là **số nguyên VND**. JSON success trả object trực tiếp. `Page<T> = {items:[T],next_cursor:string|null}`; mọi collection có kiểu Page nhận `cursor?,limit?` (mặc định 20, tối đa 100). Cursor opaque, giữ nguyên bộ lọc khi tải tiếp.
- Mọi POST tạo giao dịch, nhắn tin, xác nhận, chuyển trạng thái, tạo báo cáo hoặc đối soát yêu cầu header `Idempotency-Key` (UUID mới cho mỗi ý định, giữ nguyên khi thử lại). Không yêu cầu cho OTP, upload, báo giá hoặc đăng xuất. Backend kiểm tra quyền trước khi replay; cùng tài khoản + method + path + key + body trả lại kết quả thành công ban đầu, khác body trả 409 `idempotency_conflict`. Với key mới, quy tắc duy nhất theo đơn/người/vai trò vẫn áp dụng. Sau timeout Flutter tải lại chi tiết.
- Lỗi dùng cùng cấu trúc như ví dụ. 400 `invalid_request`; 401 `unauthenticated` (đăng nhập lại); 403 `verification_required` hoặc `forbidden`; 404 `not_found` cho tài nguyên thiếu hoặc riêng tư ngoài quyền; 422 `validation_failed`; 429 `rate_limited` kèm `Retry-After` tính bằng giây; 5xx `service_unavailable` hoặc `internal_error`. Mã 409 cụ thể theo nghiệp vụ ở dưới. Flutter phân nhánh theo code, hiển thị message tiếng Việt. fields là object ánh xạ tên trường sang thông báo, có thể rỗng.

```json
{"error":{"code":"schedule_conflict","message":"Món này đã có lịch trong khoảng ngày bạn chọn.","fields":{}}}
```

**Trình duyệt.** Web gọi cùng origin qua `/v1`, gửi Bearer và Idempotency-Key như Android. Đọc ảnh riêng qua API có xác thực. Mặc định giữ access token trong bộ nhớ của tab; khi reload và cần đăng nhập lại, giữ đường dẫn nội bộ rồi quay lại sau OTP. Khi dùng Back hoặc theo link, tải lại quyền và trạng thái đơn từ server. Web local dùng `/notifications` và bỏ qua đăng ký FCM.

## 2. Đăng nhập và duyệt sinh viên · AC-01, AC-07

`User = {id,display_name,verified:bool}` là hồ sơ hiển thị. `Me = User + {email,role:(student,admin),verification:(unsubmitted,pending,approved,rejected),full_name:string|null,student_code:string|null,class_name:string|null,faculty:string|null,review_note:string|null}`. Các trường xác minh chỉ dành cho chính chủ và quản trị viên có quyền.

| Method và path | Request | Success |
|---|---|---|
| POST /auth/otp | {email} | 202 {challenge_id,expires_at}; phản hồi cùng dạng cho mọi email hợp lệ |
| POST /auth/verify | {challenge_id,code} | 200 {access_token,expires_at,me:Me}; code là chuỗi, dùng một lần; sai hoặc hết hạn trả 401 `invalid_otp` |
| POST /auth/logout | {} | 204, thu hồi phiên hiện tại |
| GET /me | — | 200 Me |
| PUT /me/verification | {full_name,student_code,class_name,faculty,display_name} | 200 Me, chuyển pending; hồ sơ đã approved trả 409 `invalid_state` |
| GET /admin/verifications | query verification=pending | 200 Page<Me> |
| POST /admin/verifications/{user_id}/review | {decision:(approve,reject),note?:string} | 200 Me; duyệt trùng mã sinh viên trả 409 `student_code_taken` |

Giới hạn tần suất gửi/thử OTP ở backend. Không trả OTP qua API, không ghi OTP hoặc access token vào log.

## 3. Tin đăng, ảnh và báo giá · FR-01–03

`ListingInput = {title,category,description,condition,accessories:[string],photo_ids:[id],daily_rate:int,deposit:int,area,pickup_point}`. category là nhãn văn bản. areas trả đúng ["Cơ sở 1","Cơ sở 2","Cơ sở Chính"] của Đại học Sài Gòn. Flutter cho chọn một cơ sở và gửi cùng giá trị trong area và pickup_point. Backend kiểm tra danh mục và sự nhất quán khi tạo/sửa. `Listing = ListingInput + {id,owner:User,revision:int}`. revision tăng khi sửa nội dung. `Range = {start_date,end_date}`.

| Method và path | Request | Success |
|---|---|---|
| GET /catalog/options | — | 200 {categories:[string],areas:[string]} |
| GET /listings | query q?, category?, area?, min_daily_rate?, max_daily_rate?, start_date?, end_date?, mine? (bool) | 200 Page<Listing>; lọc ngày phải gửi cả cặp, chỉ trả món trống suốt khoảng |
| GET /listings/{id} | — | 200 Listing |
| POST /listings | ListingInput | 201 Listing |
| PATCH /listings/{id} | tập con khác rỗng của ListingInput | 200 Listing; yêu cầu chủ đồ |
| GET /listings/{id}/availability | query start_date,end_date | 200 {unavailable:[Range]}; không lộ người thuê |
| GET /listings/{id}/blocks | chủ đồ | 200 Page<Block>; Block = Range + {id} |
| POST /listings/{id}/blocks | Range | 201 Block; trùng lịch đã giữ trả 409 `schedule_conflict` |
| DELETE /listings/{id}/blocks/{block_id} | chủ đồ | 204 |
| POST /listings/{id}/quote | Range | 200 Quote |
| POST /photos | multipart/form-data: file (JPEG/PNG tối đa 8 MiB), purpose (listing hoặc handover), order_id bắt buộc nếu handover | 201 {id}; sai định dạng 415 `unsupported_media`, quá lớn 413 `file_too_large` |
| GET /photos/{id} | Bearer như các route khác | 200 bytes với Content-Type đúng; 404 nếu ngoài quyền |

Ảnh chưa gắn tài nguyên chỉ uploader đọc được. Khi gắn, server kiểm tra chủ sở hữu ảnh, purpose, đúng đơn và quyền của người gửi. Ảnh tin đã đăng cho người dùng đăng nhập xem. Ảnh giao trả chỉ hai bên và quản trị viên xử lý vụ việc được đọc. Nháp tin lưu ở Flutter. Backend kiểm tra nội dung ảnh thực tế.

**Quote** dưới đây là response chuẩn và fixture tiền chung. Hai ngày thuê, giá 50.000đ/ngày. Khi tạo đơn gửi lại listing_revision đã xem. Nếu sửa tin trước lúc gửi, trả 409 `quote_changed` và yêu cầu tải báo giá mới.

```json
{"listing_id":"item-1","listing_revision":1,"start_date":"2027-03-05","end_date":"2027-03-06","days":2,"daily_rate":50000,"rent":100000,"deposit":300000,"renter_fee":1000,"owner_fee":1000,"pickup_total":401000,"owner_net":99000}
```

## 4. Đơn, xác nhận và trao đổi · FR-04–07

`Order = {id,listing_id,title,owner:User,renter:User,quote:Quote,accessories:[string],pickup_point,status,close_reason:string|null,overdue:bool,blocking_order_id:id|null,pickup:[Receipt],returned:[Receipt],deposit_result:DepositResult,fee_state:(unaccrued,outstanding,settled),allowed_actions:[string],created_at}`. title, quote, accessories và pickup_point chụp tại lúc gửi yêu cầu. blocking_order_id chỉ hiện cho chủ đồ khi món đang ở tay người thuê của đơn khác; các trường hợp khác trả null. Giờ hẹn được hai bên chốt trong tin nhắn.

`Receipt = {actor_id,confirmed_at,condition,accessories:[string],photo_ids:[id],cash_received:int|null}`. cash_received là tổng tiền hai bên xác nhận đã trao, chỉ dùng lúc nhận đồ. `DepositResult = {status:(pending,disputed,agreed,resolved),refunded:int|null,reason:string|null,claims:[Claim]}`; `Claim = {actor_id,refunded:int,reason:string|null,confirmed_at}`. Mảng xác nhận cho biết bên nào còn phải thao tác. Client dịch enum sang tiếng Việt.

| Method và path | Request | Success |
|---|---|---|
| POST /orders | {listing_id,listing_revision:int,start_date,end_date,note?:string} | 201 Order; note nếu có là tin nhắn đầu. Cấm thuê đồ của chính mình. |
| GET /orders | query as=owner hoặc renter, status? | 200 Page<Order> |
| GET /orders/{id} | hai bên hoặc admin xử lý vụ việc | 200 Order |
| POST /orders/{id}/approve | {} | 200 Order |
| POST /orders/{id}/reject | {reason} | 200 Order |
| POST /orders/{id}/cancel | {reason} | 200 Order |
| POST /orders/{id}/pickup | {condition,accessories:[string],photo_ids:[id],cash_received:int} | 200 Order |
| POST /orders/{id}/return | {condition,accessories:[string],photo_ids:[id]} | 200 Order |
| POST /orders/{id}/deposit | {refunded:int,reason?:string} | 200 Order |
| GET /orders/{id}/messages | thứ tự tăng dần theo thời điểm, id phân xử khi trùng | 200 Page<Message> |
| POST /orders/{id}/messages | {text} | 201 Message; Message = {id,order_id,sender_id,text,created_at} |

**Chuyển trạng thái.** allowed_actions gồm các giá trị `approve,reject,cancel,pickup,return,deposit,message,report` hợp lệ cho người đang xem. Server kiểm tra lại khi nhận lệnh; UI tải lại đơn sau 409.

| Trạng thái | Tác nhân và kết quả |
|---|---|
| requested | Chủ đồ approve → approved, reject → rejected. Hai bên có thể cancel → cancelled. Quá end_date theo giờ Việt Nam → expired. Duyệt giữ lịch nguyên tử, đóng yêu cầu chờ chồng ngày thành rejected với close_reason="schedule_conflict". Lệnh duyệt thua cạnh tranh trả 409 schedule_conflict. |
| approved | Chỉ được cancel khi pickup rỗng. Sau xác nhận đầu tiên, bỏ cancel khỏi allowed_actions, hiện report. API cancel trả 409 `pickup_started`. Mỗi bên pickup một lần trong khoảng thuê. Server kiểm tra số tiền bằng pickup_total. Khi đủ hai xác nhận, cùng giao dịch mở phiếu, chuyển active và fee_state sang outstanding. Nếu món đang ở tay người khác, trả 409 item_not_returned. |
| active | Mỗi bên return một lần. Hai xác nhận trả → returned, giải phóng món. overdue=true khi đã qua end_date và phiếu vẫn mở. Ghi nhận ảnh và tình trạng riêng của mỗi bên. |
| returned | Mỗi bên khai kết quả cọc từ 0 đến deposit, cần reason khi khấu trừ. Hai số tiền khớp → agreed và completed. Khác nhau → disputed, mở một vụ việc về cọc. Nếu cọc bằng 0, đủ hai xác nhận trả → agreed với refunded=0 và completed ngay. |
| completed, cancelled, rejected, expired | Không nhận thêm xác nhận giao trả. Đơn completed vẫn có thể có phí outstanding. |

Chỉ vai trò được nêu mới được hành động. 409 `invalid_state` khi lệnh đã lỗi thời. Với xác nhận cùng loại từ cùng người, payload giống nhau trả thành công và không tạo bản thứ hai, payload khác trả 409 `confirmation_conflict`. Dù gửi lại bằng key khác vẫn chỉ phát sinh một lần phí mỗi vai trò. Sau một xác nhận, tạo case loại `handover` nếu có bất đồng. Đơn vẫn approved, giữ lịch, phí 0đ. Khi case mở, bỏ pickup khỏi allowed_actions, POST pickup mới trả 409 `handover_disputed`. Các lệnh pickup/cancel/mở case đồng thời phải kiểm tra trạng thái nguyên tử.

**Request mẫu** cho POST /orders; response đầy đủ dưới đây cũng dùng làm mẫu GET /orders/{id} cho người thuê.

```json
{"listing_id":"item-1","listing_revision":1,"start_date":"2027-03-05","end_date":"2027-03-06","note":"Mình hẹn ở Cơ sở Chính nhé."}
```

```json
{"id":"order-1","listing_id":"item-1","title":"Máy ảnh","owner":{"id":"user-a","display_name":"Chủ đồ mẫu","verified":true},"renter":{"id":"user-b","display_name":"Người thuê mẫu","verified":true},"quote":{"listing_id":"item-1","listing_revision":1,"start_date":"2027-03-05","end_date":"2027-03-06","days":2,"daily_rate":50000,"rent":100000,"deposit":300000,"renter_fee":1000,"owner_fee":1000,"pickup_total":401000,"owner_net":99000},"accessories":["Pin"],"pickup_point":"Cơ sở Chính","status":"requested","close_reason":null,"overdue":false,"blocking_order_id":null,"pickup":[],"returned":[],"deposit_result":{"status":"pending","refunded":null,"reason":null,"claims":[]},"fee_state":"unaccrued","allowed_actions":["cancel","message","report"],"created_at":"2027-03-01T03:00:00Z"}
```

## 5. Sự cố, phí và quản trị · FR-08, AC-06–07

`Case = {id,target_type:(listing,order),target_id,reporter_id,category,detail,status:(open,resolved),resolution:string|null,created_at}`. category thuộc listing_content, description, accessory, damage, overdue, deposit, handover, other. Chi tiết đơn và bằng chứng chỉ dành cho hai bên hoặc quản trị viên xử lý.

| Method và path | Request | Success |
|---|---|---|
| POST /cases | {target_type,target_id,category,detail} | 201 Case; báo cáo theo đơn cần là một bên của đơn |
| GET /cases | các vụ việc được phép xem của người dùng | 200 Page<Case> |
| GET /cases/{id} | người báo, bên liên quan của đơn hoặc admin xử lý | 200 Case |
| GET /admin/cases | query status?,target_type? | 200 Page<Case> |
| POST /admin/cases/{id}/resolve | {resolution,refunded?:int,handover_outcome?:(resume,cancel_unhanded)} | 200 Case; với tranh chấp cọc sau khi trả, bắt buộc refunded hợp lệ, ghi deposit_result.resolved, cập nhật số tiền, lý do và hoàn tất đơn nguyên tử |
| GET /fees/summary | chủ đồ hiện tại | 200 FeeSummary |
| GET /fees/entries | query state? | 200 Page<FeeEntry> |
| GET /admin/fees/owners | danh sách chủ đồ có phát sinh | 200 Page<OwnerFees>; OwnerFees = {owner:User,summary:FeeSummary} |
| GET /admin/fees/owners/{id}/entries | query state? | 200 Page<FeeEntry> |
| POST /admin/settlements | {owner_id,order_ids:[id],received_amount:int,reference} | 201 Settlement; sau khi xác minh thực nhận |
| GET /settlements | chủ đồ hiện tại, mới nhất trước | 200 Page<Settlement> |

`FeeSummary = {accrued:int,settled:int,outstanding:int}`. `FeeEntry = {order_id,accrued_at,renter_fee:int,owner_fee:int,total:int,state:(outstanding,settled),settlement_id:id|null}`. `Settlement = {id,owner_id,order_ids:[id],received_amount:int,reference,confirmed_at,confirmed_by}`. Mỗi dòng phí bằng 2.000đ từ lúc giao thành công. Khi đối soát, order_ids duy nhất, thuộc cùng chủ đồ, còn outstanding và tổng phải bằng received_amount. Chuyển toàn bộ hoặc giữ nguyên toàn bộ; đơn đã được đối soát qua giao dịch khác trả 409 `already_settled`. Từ chối khoản tiền lệch với 422.

Với case handover, chỉ cho mở khi đơn approved và có đúng một xác nhận; tối đa một case handover đang mở mỗi đơn. Khi resolve, bắt buộc handover_outcome. resume giữ xác nhận đầu và mở lại thao tác pickup cho bên còn lại. cancel_unhanded chuyển cancelled, giữ lịch sử, giải phóng lịch và giữ phí bằng 0. Ghi quyết định và cập nhật đơn trong cùng giao dịch.

## 6. Thông báo · FR-09, AC-08

| Method và path | Request | Success |
|---|---|---|
| PUT /me/devices/{installation_id} | {fcm_token} | 204; gắn/cập nhật thiết bị của phiên |
| DELETE /me/devices/{installation_id} | trước đăng xuất trên thiết bị | 204 |
| GET /notifications | danh sách của chính mình, mới nhất trước | 200 Page<Notice> |
| PUT /notifications/{id}/read | {} | 200 Notice |

`Notice = {id,type,title,body,target_type:(order,case),target_id,read_at:timestamp|null,created_at}`. Push chứa `notification_id,target_type,target_id`. Flutter tải lại tài nguyên có xác thực khi mở. Không đưa tin nhắn riêng, chi tiết tiền cọc hoặc ảnh vào push. Token thiết bị phải được ràng buộc với tài khoản hiện tại khi đổi người dùng.

**Go → Go.** Worker outbox của rental gọi `POST /internal/v1/events` của notification, chỉ trên mạng dịch vụ, dùng credential riêng cho service qua header Authorization Bearer. Payload `{event_id,type,occurred_at,target_type,target_id,recipient_ids:[id]}`. type thuộc `order_requested,order_approved,order_closed,pickup_confirmed,return_due,order_overdue,return_confirmed,case_opened,case_resolved`. Notification tạo nội dung tiếng Việt theo type. Trả 204 sau khi lưu bền vững inbox/công việc gửi; cùng event_id đến lại trả 204, mỗi người nhận chỉ có một notice cho sự kiện. Worker thử lại khi timeout/5xx. Các route /notifications và /me/devices được định tuyến tới notification; route public còn lại tới rental. Cả hai xác minh cùng danh tính phiên và việc thu hồi.

## 7. Ghép frontend và backend

| Tình huống | Kỳ vọng để chạy trên cả mock Flutter và Go |
|---|---|
| Khám phá | Danh sách rỗng trả 200 với items rỗng và next_cursor=null. Chọn ngày trùng lịch khiến món biến mất khỏi kết quả. |
| Báo giá và duyệt | Dùng fixture §3–4. Thay revision trước tạo đơn → quote_changed; hai lần duyệt đơn chồng lịch → một approved, một schedule_conflict. |
| Giao trả | Một xác nhận giao → approved và unaccrued; đủ hai → active và outstanding. Trả đồ nhưng bất đồng cọc → returned và disputed, món có thể giao tiếp. |
| Quyền và retry | Người ngoài đọc ảnh/đơn riêng → 404. Thử lại sau mất mạng không thêm biên nhận. Hủy trước giao không tạo dòng phí. |
| Đối soát và thông báo | Năm đơn outstanding → 10.000đ. Replay cùng key vẫn một Settlement. Tạm tắt notification khi duyệt rồi khởi động lại → đơn vẫn approved, một notice mỗi người nhận. |

Flutter có thể bắt đầu từ fixture và bảng chuyển trạng thái; giữ mapping JSON ở lớp gọi API. Go kiểm tra status, payload và quyền theo cùng ví dụ. Khi tích hợp, chạy lại kịch bản hai tài khoản trên backend thật và kiểm tra cạnh tranh bằng PostgreSQL. Ngày trong fixture là dữ liệu cố định; dùng đồng hồ test tương ứng khi kiểm thử thời hạn.

# Chạy giao diện web REIMS

Giao diện Flask kết nối đến MySQL Server. Database mới: chạy `01_schema.sql`, sau đó `02_data4000.sql`. Database đã có dữ liệu: giữ nguyên database và chạy migration còn thiếu `05_auth_migration.sql` (nếu chưa có tài khoản) rồi `06_finance_migration.sql`.

## Khởi động nhanh

- Linux/macOS: chạy `run_ui.sh` trong thư mục `ui`.
- Windows: nhấp đúp `run_ui.bat`.

Launcher tự tạo môi trường Python và cài thư viện khi cần. Mặc định, ứng dụng kết nối đến `127.0.0.1:3306`, database `reims_db`, user `root`, mật khẩu `1`. Có thể đặt các biến `REIMS_DB_HOST`, `REIMS_DB_PORT`, `REIMS_DB_USER`, `REIMS_DB_PASSWORD`, `REIMS_DB_NAME` trước khi chạy để dùng thông tin khác.

Mở <http://127.0.0.1:5000>. MySQL Server phải đang chạy.

## Đăng nhập và phân quyền

Nếu database chưa có tài khoản Admin, web sẽ hiện trang tạo Admin đầu tiên. Sau khi đăng nhập, vào **Accounts** để tạo login cho Agent, Owner, Tenant hoặc Buyer. Mỗi account được gắn với hồ sơ đúng vai trò; mật khẩu được lưu dưới dạng hash, bắt buộc nhập và tối đa 128 ký tự. Admin có thể vô hiệu hóa account.

Quyền được xác thực ở server trên mỗi request. Admin quản lý toàn hệ thống; Agent chỉ sửa tin đăng và chuẩn bị lease cho bất động sản được giao; Owner chỉ xem dữ liệu thuộc bất động sản của mình; Tenant/Buyer chỉ xem dữ liệu cá nhân và tạo yêu cầu lease, payment hoặc bảo trì trong phạm vi lease của họ. Chỉ Admin được duyệt/từ chối lease, phân công Agent và cập nhật tiến độ bảo trì.

## Chức năng hiện có

- Xem dashboard theo phạm vi actor.
- Tìm kiếm bất động sản theo quyền; Admin tạo tài sản và phân công Agent.
- Agent cập nhật giá/loại tin đăng của tài sản được giao.
- Tạo lease ở trạng thái PENDING; Admin duyệt hoặc từ chối.
- Tạo hóa đơn thuê theo tháng, theo dõi khoản đã thu, số dư, khoản đến hạn/quá hạn.
- Ghi payment gắn invoice; kiểm tra số dư, transaction reference, idempotency key và khoản gửi trùng.
- Gửi offer giao dịch bán, Admin duyệt/chốt, lưu hoa hồng theo tỷ lệ tại thời điểm giao dịch.
- Xem thông báo hóa đơn, lease sắp/đã hết hạn và cập nhật giao dịch bán; lease quá ngày kết thúc được tự chuyển sang `EXPIRED` khi thông báo được làm mới.
- Tạo yêu cầu bảo trì; Admin cập nhật tiến độ.

Thông báo được làm mới khi mở trang Invoices hoặc Notifications. Hóa đơn demo dùng tháng lịch và chưa tính tiền prorate cho tháng lẻ.

# Chạy giao diện web REIMS

Giao diện Flask kết nối đến MySQL Server. Database mới: chạy `01_schema.sql` và `02_seed_1000_plus.sql` trong MySQL Workbench. Database đã có dữ liệu cần giữ: chạy riêng `05_auth_migration.sql` để thêm phân quyền mà không xóa dữ liệu.

## Khởi động nhanh

- Linux/macOS: chạy `run_ui.sh` trong thư mục `ui`.
- Windows: nhấp đúp `run_ui.bat`.

Launcher tự tạo môi trường Python và cài thư viện khi cần. Mặc định, ứng dụng kết nối đến `127.0.0.1:3306`, database `reims_db`, user `root`, mật khẩu `1`. Có thể đặt các biến `REIMS_DB_HOST`, `REIMS_DB_PORT`, `REIMS_DB_USER`, `REIMS_DB_PASSWORD`, `REIMS_DB_NAME` trước khi chạy để dùng thông tin khác.

Mở <http://127.0.0.1:5000>. MySQL Server phải đang chạy.

## Đăng nhập và phân quyền

Nếu database chưa có tài khoản Admin, web sẽ hiện trang tạo Admin đầu tiên. Sau khi đăng nhập, vào **Accounts** để tạo login cho Agent, Owner, Tenant hoặc Buyer. Mỗi account được gắn với hồ sơ đúng vai trò; mật khẩu tối thiểu 12 ký tự và được lưu dưới dạng hash. Admin có thể vô hiệu hóa account.

Quyền được xác thực ở server trên mỗi request. Admin quản lý toàn hệ thống; Agent chỉ sửa tin đăng và chuẩn bị lease cho bất động sản được giao; Owner chỉ xem dữ liệu thuộc bất động sản của mình; Tenant/Buyer chỉ xem dữ liệu cá nhân và tạo yêu cầu lease, payment hoặc bảo trì trong phạm vi lease của họ. Chỉ Admin được duyệt/từ chối lease, phân công Agent và cập nhật tiến độ bảo trì.

## Chức năng hiện có

- Xem dashboard theo phạm vi actor.
- Tìm kiếm bất động sản theo quyền; Admin tạo tài sản và phân công Agent.
- Agent cập nhật giá/loại tin đăng của tài sản được giao.
- Tạo lease ở trạng thái PENDING; Admin duyệt hoặc từ chối.
- Ghi và xem payment theo phạm vi quyền.
- Tạo yêu cầu bảo trì; Admin cập nhật tiến độ.

Lịch xem nhà, thông báo hết hạn/quá hạn, hóa đơn định kỳ/công nợ, quy trình chốt giao dịch bán/tính hoa hồng và nhật ký lịch sử trạng thái vẫn là hướng phát triển tiếp theo.

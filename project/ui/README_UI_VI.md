# Chạy giao diện web REIMS

Giao diện Flask kết nối đến MySQL Server. Trước khi chạy UI, khởi tạo `reims_db` theo thứ tự trong [`../sql/README_VI.md`](../sql/README_VI.md). Sau khi tạo Admin đầu tiên qua `/setup`, có thể nạp dữ liệu demo bằng `sql/seed/01_data4000.sql`.

## Khởi động nhanh

- Linux/macOS: chạy `run_ui.sh` trong thư mục `ui`.
- Windows: nhấp đúp `run_ui.bat`.

Launcher tự tạo môi trường Python và cài thư viện khi cần. Mặc định, ứng dụng kết nối đến `127.0.0.1:3306`, database `reims_db`, user `root`, mật khẩu `1`. Có thể đặt các biến `REIMS_DB_HOST`, `REIMS_DB_PORT`, `REIMS_DB_USER`, `REIMS_DB_PASSWORD`, `REIMS_DB_NAME` trước khi chạy để dùng thông tin khác.

Mở <http://127.0.0.1:5000>. MySQL Server phải đang chạy.

## Đăng nhập và phân quyền

Nếu database chưa có tài khoản Admin, web sẽ hiện trang tạo Admin đầu tiên. Sau khi đăng nhập, vào **Accounts** để tạo login cho Agent, Owner, Tenant hoặc Buyer. Mỗi account được gắn với hồ sơ đúng vai trò; mật khẩu được lưu dưới dạng hash, bắt buộc nhập và tối đa 128 ký tự. Admin có thể vô hiệu hóa account.

## Chức năng hiện có

- Dashboard theo phạm vi actor; quản lý tài sản và phân công Agent.
- Tạo lease PENDING và để Admin duyệt hoặc từ chối.
- Tạo hóa đơn thuê theo tháng, xem công nợ và ghi nhận thanh toán.
- Gửi offer bán, Admin duyệt/chốt và lưu hoa hồng theo tỷ lệ tại thời điểm giao dịch.
- Thông báo về hóa đơn, lease và giao dịch bán.
- Tạo yêu cầu bảo trì và để Admin cập nhật tiến độ.

Hóa đơn và thông báo được làm mới khi trang liên quan được mở hoặc Admin tạo hóa đơn; chưa có MySQL Event chạy nền. Hóa đơn demo dùng tháng lịch và chưa tính tiền prorate cho tháng lẻ.

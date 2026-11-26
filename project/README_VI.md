# REIMS — Real Estate Property & Rental Ledger

REIMS là đồ án quản lý bất động sản, hợp đồng thuê, hóa đơn thuê, khoản thu, giao dịch bán, hoa hồng, bảo trì và thông báo. Database dùng MySQL 8; giao diện dùng Flask.

## Tính năng chính

- Quản lý tài sản bán/cho thuê, chủ sở hữu, agent, tenant/buyer và lease.
- Admin duyệt lease và giao dịch bán; trạng thái tài sản được đồng bộ khi lease bắt đầu/kết thúc, bảo trì và bán hoàn tất.
- Tạo một hóa đơn cho mỗi tháng trong thời hạn lease. Khoản RENT phải gắn với hóa đơn; view tính tiền đã thu, số dư và tình trạng đến hạn/quá hạn.
- Ghi nhận khoản thanh toán theo invoice, transaction reference và idempotency key. Giao diện chặn gửi lại khoản giống hệt; database chặn dùng lại cùng idempotency key hoặc transaction reference.
- Lưu giao dịch bán và tỷ lệ hoa hồng tại thời điểm chốt; hoa hồng chỉ được tính là đã phát sinh khi sale ở trạng thái CLOSED.
- Tạo thông báo trong ứng dụng cho hóa đơn sắp đến hạn/quá hạn, lease sắp hết hạn/đã hết hạn và thay đổi trạng thái giao dịch bán. Lease quá ngày kết thúc được chuyển sang `EXPIRED` khi quy trình làm mới thông báo chạy.
- Phân quyền theo ADMIN, AGENT, OWNER và TENANT/BUYER; kiểm tra quyền ở phía server.

Thông báo được làm mới khi người dùng mở trang Invoices hoặc Notifications. Hệ thống demo tạo hóa đơn theo tháng lịch và tính trọn monthly_rent cho tháng đầu/cuối; chưa prorate tháng lẻ. Đây là mô hình đồ án, không phải tích hợp cổng thanh toán thực tế.

## Các bảng

Schema có 14 bảng: `person`, `user_account`, `owner`, `agent`, `tenant`, `property`, `residential_property`, `commercial_property`, `lease`, `rental_invoice`, `payment`, `sale_transaction`, `maintenance_request`, `notification`. `v_invoice_balance`, `v_overdue_invoices` và `v_property_dashboard` là views, không phải bảng lưu dữ liệu.

## Tạo database mới

Trong MySQL Workbench, chạy theo thứ tự:

1. `01_schema.sql` — tạo lại các đối tượng trong database `reims_db`; thao tác này xóa dữ liệu REIMS hiện có.
2. `02_data4000.sql` — thêm dữ liệu demo (ít nhất 4.000 bản ghi).
3. `03_queries.sql` — chạy các truy vấn minh họa khi cần.

## Nâng cấp database đã có dữ liệu

Không chạy lại `01_schema.sql` nếu cần giữ dữ liệu. Chạy migration theo thứ tự phù hợp với database:

1. `05_auth_migration.sql` nếu database cũ chưa có tài khoản và phân quyền.
2. `06_finance_migration.sql` để thêm invoice, sale transaction, notification và cơ chế chống gửi payment lặp.

Migration `06` không xóa bản ghi hiện có. Khoản RENT cũ được gắn với hóa đơn tháng tương ứng khi có thể suy ra từ ngày thu; khoản cọc, phí và hoàn tiền cũ để nguyên vì schema trước không lưu đủ thông tin để suy luận hóa đơn chính xác. File có truy vấn liệt kê nhóm payment trùng tiềm năng; cần đối chiếu trước khi xử lý vì hai khoản cùng số tiền/ngày vẫn có thể là hai lần trả góp hợp lệ.

## Chạy giao diện

MySQL Server cần chạy và database cần được khởi tạo. Trong thư mục `ui`, chạy `run_ui.sh` (Linux/macOS) hoặc `run_ui.bat` (Windows), rồi mở <http://127.0.0.1:5000>. Launcher mặc định dùng `127.0.0.1:3306`, database `reims_db`, user `root`, password `1`; có thể thay bằng biến môi trường `REIMS_DB_HOST`, `REIMS_DB_PORT`, `REIMS_DB_USER`, `REIMS_DB_PASSWORD`, `REIMS_DB_NAME`.

Nếu chưa có Admin, trang `/setup` cho phép tạo tài khoản đầu tiên. Mật khẩu được lưu dưới dạng hash; giới hạn tối đa 128 ký tự, không đặt độ dài tối thiểu.

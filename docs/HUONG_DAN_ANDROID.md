# Hướng dẫn cài đặt và nghiệm thu ZalGps Android

Phiên bản thử nghiệm: **10.2.0-beta.5+163**. Bản APK đã ký chính thức; hiện là draft trên GitHub, chưa công bố rộng rãi. Xem [bằng chứng build](BUILD_STATUS.md).

## 1. Nâng cấp

1. Đăng nhập tài khoản GitHub có quyền truy cập draft trên [trang Releases](https://github.com/minhtuancn/traccar-client/releases).
2. Tải APK release và file SHA-256 đi kèm. Kiểm tra checksum.
3. Cài đè lên beta.3 hoặc beta.4 đã ký cùng khóa. Không xóa dữ liệu hoặc gỡ ứng dụng đang sử dụng.
4. Mở ZalGps, kiểm tra mục **Đăng ký thiết bị ZalGps** ở đầu màn hình, ID, URL máy chủ và thông số cũ.

Nếu Android báo chữ ký không tương thích, dừng lại để kiểm tra bản đang cài. Không gỡ bản cũ khi chưa xác minh dữ liệu GPS đang chờ gửi.

## 2. Đã có thiết bị trên Traccar

- Đối chiếu ID trên app với mã định danh (uniqueId) trên dashboard, không dùng số thứ tự database.
- Quản trị viên cấp quyền cho tài khoản dịch vụ ZalGPS đối với đúng thiết bị hiện có.
- Tắt theo dõi, sao chép ID, yêu cầu quản trị viên cấp mã liên kết dành riêng cho ID đó (xem [hướng dẫn backend](../provisioning/README.md)).
- Chọn **Liên kết thiết bị hiện có**, nhập mã trong thời hạn 15 phút.
- Xác nhận tên và ID trên app không đổi; dashboard không có thiết bị trùng.
- Đóng và mở lại app; kiểm tra trạng thái đăng ký còn hiển thị.

Không dùng mã tạo thiết bị mới cho thiết bị đã đăng ký thủ công. Không gửi mã kích hoạt qua chat, issue hoặc log.

## 3. Điện thoại cài mới

Chỉ trên thiết bị được phép theo dõi, chưa có cấu hình/tracking: yêu cầu mã đăng ký mới, chọn **Đăng ký thiết bị**, nhập mã và đối chiếu ID mới với dashboard. Việc đăng ký không tự bật GPS; người dùng chủ động bật theo dõi và cấp quyền Android.

## 4. Xử lý lỗi

| Hiện tượng | Kiểm tra |
| --- | --- |
| Không có thẻ đăng ký | Kiểm tra đúng beta.5; beta.4 có lỗi ẩn nút. |
| Nút tạo ID mới không có | App đã cấu hình ID hoặc đã chạy tracking; dùng luồng liên kết ID hiện có. |
| Nút liên kết bị vô hiệu | Dừng tracking; kiểm tra URL đúng máy chủ ZalGps. |
| Mã bị từ chối | Kiểm tra thời hạn, loại mã, ID, quyền tài khoản dịch vụ và thiết bị chưa bị vô hiệu hóa. |
| Đã liên kết nhưng không có vị trí | Kiểm tra quyền vị trí, GPS, kết nối và Status/queue; chủ động bật tracking. |
| Không thấy thông báo foreground | Kiểm tra quyền thông báo và thiết lập Android, không bỏ qua yêu cầu hiển thị của hệ điều hành. |

## 5. Nghiệm thu trên thiết bị thật

- [ ] Cài đè beta.4 không mất ID, URL, cấu hình và vị trí chờ gửi.
- [ ] Liên kết ID cũ thành công, không có thiết bị trùng.
- [ ] Cài mới trên điện thoại thử nghiệm khác, đăng ký bằng mã mới.
- [ ] Mở lại ứng dụng, trạng thái còn hiển thị.
- [ ] Theo dõi chỉ bắt đầu sau thao tác chủ động và quyền hợp lệ.
- [ ] Vị trí thực tế xuất hiện trên Traccar.
- [ ] Mất mạng rồi có mạng: queue được giữ và gửi lại.
- [ ] Explicit Stop vẫn dừng sau reboot/watchdog.

Báo kết quả PASS/FAIL, phiên bản Android, phiên bản app và lỗi đã loại bỏ dữ liệu cá nhân. Không đưa tọa độ, token hoặc mã kích hoạt vào repo công khai.

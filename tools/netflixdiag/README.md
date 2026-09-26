# NetflixDiag 0.1.0

Gói chẩn đoán chỉ đọc, chỉ nạp vào `com.netflix.Netflix`. Không hook SpringBoard, CarPlayApp, AVPlayer; không thay đổi luồng phát, DRM hay cài đặt ConnectTA.

## Ghi nhận

Log tối đa 512 KiB tại `/var/mobile/NetflixDiag.log`. Ghi phiên bản iOS/model, topology màn hình, trạng thái captured/mirrored, scene bounds, audio route, và domain/code lỗi AVPlayer nếu ứng dụng phát notification tương ứng. Không ghi tên phim, URL phát, thông tin tài khoản, hay khung hình.

## Test

1. Khôi phục máy khỏi vòng respring và gỡ ConnectTA 0.4.6 nếu còn cài.
2. Cài NetflixDiag, đóng hẳn Netflix rồi mở lại; gói không yêu cầu đổi cài đặt ConnectTA.
3. Kết nối CarPlay; mở Netflix, chạy một trailer rồi thử một phim. Ghi lại giờ bấm Play và chụp nguyên thông báo lỗi/mã lỗi.
4. Trong Filza mở `/var/mobile/NetflixDiag.log`, gửi log đó cùng ảnh lỗi.
5. Gỡ NetflixDiag trong Sileo sau khi lấy log.

Gói này chỉ thu thập trạng thái phục vụ chẩn đoán. Nó không biến màn hình CarPlay thành đầu ra Netflix được hỗ trợ.

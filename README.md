# MiniTa — App Bridge

Jailbreak tweak đưa giao diện app iPhone được chọn lên Home CarPlay. Gói hiện tại dành cho Dopamine rootless, chưa kiểm chứng RootHide.

## Mốc phiên bản

- `checkpoint-88-host-working`: bản YouTube 0.2.88 đã thử trên thiết bị; giữ nguyên để quay lại.
- `feature-appbridge-90`: bản thử 0.3.0, danh sách app và ON/OFF trong Cài đặt → MiniTa. Chưa khẳng định mọi app tương thích.
- Bản dọn 89 không phát hành riêng; phần bỏ host phủ cũ và giảm log được đưa vào 90.

## Cài và sử dụng

1. Ngắt CarPlay, cài DEB rootless cùng PreferenceLoader, respring.
2. Vào **Cài đặt → MiniTa**. Mặc định chỉ YouTube bật. Bật A510Player hoặc app muốn thử.
3. Tắt CarBridge cho cùng app. Đóng hẳn app rồi mở lại trên iPhone; respring và kết nối lại CarPlay để cập nhật Home.
4. Mở icon từ Home CarPlay. Nếu A510 cần khởi động luồng camera trước, vẫn phải thực hiện bước đó: MiniTa không thay phần kết nối camera.
5. Muốn ngừng bridge: OFF, đóng app và respring khi đã ngắt CarPlay. OFF giữ hành vi CarPlay gốc, không xoá icon gốc của app có CarPlay.

Chỉ thử video khi xe đỗ. Không bật cùng app trong hai tweak bridge.

## Thiết kế và giới hạn

- Danh sách app được lấy qua LaunchServices, không cần nhập bundle ID. Không liệt kê bundle Apple/hệ thống; app có CarPlay gốc không tự động bị bật.
- Cấu hình dùng CFPreferences domain `com.sushibta.minita`, key `EnabledApps`. Mảng rỗng có nghĩa tắt hết; chưa có cấu hình mặc định chỉ bật YouTube.
- Dylib được loader nạp vào các tiến trình UIKit để có thể chọn app bất kỳ. App không được chọn thoát sớm, không cài hook app/observer/timer. Không có cập nhật filter động cần quyền root.
- Chỉ YouTube dùng giả lập iPad và canvas 1024 point. App khác layout theo kích thước thật của vùng CarPlay.
- App bridge chuyển root view controller của cửa sổ iPhone sang scene CarPlay, phục hồi khi ngắt kết nối. Cửa sổ phụ, camera, bàn phím, DRM và các app có lifecycle riêng cần thử riêng.
- Bubble không được tạo lại: VMLbubble và bản rebuild v3.0.1 phải kiểm tra tương thích riêng.
- Không đổi cấu hình khi đang chạy CarPlay. Hook phía app được chọn lúc khởi động; phải đóng/mở app để áp dụng ON/OFF.
- Log tối đa khoảng 1 MiB mỗi file: `/var/mobile/MiniTa.txt`, `/var/mobile/MiniTa-admission.txt`, `Documents/MiniTa-client.txt` trong app được bridge.

## Kiểm thử thiết bị cần làm

- YouTube: icon, cuộn, tìm kiếm, fullscreen, Home/reopen, ngắt/nối lại.
- A510Player (`com.sushibta.a510player`): ON xuất hiện, nhận chạm, xem luồng, OFF trả về bình thường.
- App khác: một app chỉ hỗ trợ dọc; một app có CarPlay gốc để thử OFF không làm mất chức năng gốc.
- Tắt toàn bộ: không còn icon do MiniTa thêm sau respring/reconnect.
- Bubble: thử VMLbubble riêng, không mặc định bản rebuild sẽ tương thích.

## Build

Theos, iPhoneOS SDK, `make clean package FINALPACKAGE=1`. Workflow tạo gói rootless cho arm64/arm64e và PreferenceBundle. CI pass chỉ xác nhận build, không thay cho kiểm thử CarPlay thật.

Tên repo có thể đổi mà không cần đổi bundle ID hoặc package ID. Không đổi hai ID đó chỉ để đổi tên repo.

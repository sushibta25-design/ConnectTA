# MiniTa 92 — adaptive YouTube experiment

Rootless package version 0.3.2. Based on build 91; checkpoint-91-configbridge and checkpoint-88-host-working remain available.

YouTube now receives phone/compact traits in a narrow CarPlay pane and iPad/regular traits in a wide pane. The original app controller is retained; this code does not seek, pause, restart or replace the player. Global UIDevice/UITraitCollection idiom hooks have been removed. The override is removed when the content returns to the iPhone.

A stable density of 2.4 logical points per CarPlay point replaces the fixed 1024-point canvas. First layout uses iPad at logical width 700 or greater. Subsequently it switches to phone at 620 or below, and back to iPad at 700 or above. The gap prevents mode flicker around the divider threshold. These are experimental tuning values.

Validation: C tests exercise both directions and hysteresis; package checks validate configuration. UIKit/YouTube behavior still requires a device test. YouTube may cache device identity rather than honor changing child traits. Split software must deliver actual pane dimensions to the client scene; host-only scaling cannot trigger this layout. Build 92 does not modify the split engine.

Device check: fully close YouTube before reconnecting after installation. Compare narrow and wide Home layouts, then drag the divider with a video playing and check continuity and touch alignment. Disconnect and verify ordinary iPhone layout. Client log contains ADAPTIVE92 with mode, viewport and logical width.

Known separate issues: reverse-camera playback recovery remains unresolved; leave TAsmart OFF in MiniTa to preserve its working CarPlay route.

---

# MiniTa 91 — sửa cơ chế App Bridge

Bản thử rootless 0.3.1 sửa kênh đọc ON/OFF trong app: SpringBoard/Cài đặt xuất trạng thái qua Darwin notify; app không cần đọc được preference domain bên ngoài sandbox để biết mình được bật. Bổ sung bộ lọc UIKitCore. Đây là sửa nguyên nhân nghi ngờ sau khi bản 90 chỉ chạy YouTube; chưa có xác nhận thiết bị.

Log `/var/mobile/MiniTa.txt` có `[CLIENT91] bundle=... stage=...` để phân biệt không nạp bridge, chưa có scene, chưa có root và đã gắn root. Không sửa mã TAsmart/A510 hoặc mặc định app đó không tương thích.

Cài bản này rồi respring (cần SpringBoard xuất cấu hình); giữ app muốn thử ON, đóng hẳn và mở lại app, kết nối lại CarPlay. Nếu vẫn đen, gửi MiniTa.txt của bản 91. YouTube giữ cách layout riêng. Bản 88 được giữ nguyên ở checkpoint.

---

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

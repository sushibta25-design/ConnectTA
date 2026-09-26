# ConnectTA

Jailbreak app bridge đưa giao diện app iPhone được chọn lên Home CarPlay. Gói thử 0.4.8 dành cho Dopamine rootless, arm64/arm64e, iOS 15 trở lên; chưa xác nhận RootHide.

## Chức năng giữ lại

- Icon app trên Home CarPlay và mở trực tiếp app đã bật.
- Danh sách bật/tắt trong Cài đặt → ConnectTA; mặc định YouTube ON.
- Netflix ON thử external-display bằng dylib riêng; Netflix OFF giữ đường hiện tại.
- YouTube, Maps, Vietmap, Zalo và mọi app khác giữ nguyên đường xử lý 0.4.0.
- Bố cục YouTube tablet 1024 điểm từ nền 91; app khác dùng kích thước vùng CarPlay.
- Căn khung, safe area, admission và truyền cấu hình giữa tiến trình.

## Nâng cấp

Ngắt CarPlay, cài DEB, respring và đóng/mở lại app được bridge. Gói ConnectTA thay thế gói com.sushibta.minita để tránh nạp hai dylib. Cấu hình mới dùng com.sushibta.connectta; nếu chưa lưu cấu hình mới sẽ đọc lựa chọn cũ. Mảng rỗng vẫn nghĩa là OFF toàn bộ. Tên cũ chỉ còn ở phần tương thích nâng cấp.

Không bật cùng app trong hai tweak bridge. Không khẳng định mọi app đều tương thích.

## Phạm vi

ConnectTA quản lý app bridge. Chia màn, divider và bàn phím chung thuộc MultiTA/TAduo; bubble thuộc dự án riêng. Không có tính năng chia màn hoặc bubble trong gói này.

Bản này không sửa lỗi phát tiếp sau camera lùi. Căn khung với bộ chia màn cần thử trên thiết bị. Bản adaptive phone/iPad 92 không được đưa vào bản dọn vì thử nghiệm chưa đạt.

## Chẩn đoán và build

Log giới hạn khoảng 1 MiB/file: /var/mobile/ConnectTA.txt, /var/mobile/ConnectTA-admission.txt và Documents/ConnectTA-client.txt trong app. Giữ lỗi và các mốc lifecycle; bỏ log resize liên tục, NSLog trùng và kênh client80 cũ. Không thêm polling thường trực.

Build: Theos + iPhoneOS SDK; make clean package FINALPACKAGE=1. Bản thử 0.4.8 cô lập kỹ thuật external-display của Netflix vào dylib riêng dựa trên ZIP do người dùng cung cấp. CI chỉ xác nhận cấu hình và biên dịch; Netflix vẫn cần thử ON/OFF trên máy thật. Các app còn lại giữ nguyên code 0.4.0.

## Mốc khôi phục

- archive-pre-connectta-main: main A/B cũ trước khi dọn.
- checkpoint-88-host-working: mốc YouTube đã kiểm chứng trước đây.
- checkpoint-91-configbridge: nền cấu hình được giữ lại.
- feature-appbridge-90: lịch sử thử nghiệm 92, không phải bản phát hành hiện tại.

Xem AUDIT.md về nội dung dọn.

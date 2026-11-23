# MultiZalo (iOS 17+) — Sử Dụng Nhiều Tài Khoản Zalo Trên iPhone / iPad

**MultiZalo** là ứng dụng iOS mã nguồn mở (viết bằng **SwiftUI + WebKit**) cho phép đăng nhập và giữ **nhiều tài khoản Zalo Web (`chat.zalo.me`) chạy song song** trên cùng một iPhone hoặc iPad mà không cần đăng xuất qua lại.

## Tính năng chính

- **Tách biệt dữ liệu hoàn toàn (`WKWebsiteDataStore(forIdentifier:)`):** Mỗi tài khoản có bộ cookie, localStorage và cache riêng trên iOS 17+.
- **Chạy song song & chuyển tab tức thì (0ms):** Các phiên đã mở được giữ nguyên trong bộ nhớ để chuyển đổi qua lại không cần tải lại trang.
- **Thông báo tin nhắn chưa đọc ngay trên tab:** Tự động nhận diện số tin nhắn mới `(N)` từ tiêu đề Zalo Web.
- **Ngủ đông phiên nền (Giải phóng RAM):** Đóng bớt các tab không dùng để tiết kiệm bộ nhớ mà vẫn giữ nguyên trạng thái đăng nhập.
- **Thu phóng linh hoạt & lưu tệp:** Điều chỉnh mức zoom (60%–140%), tự chặn chuyển hướng sang App Store, hỗ trợ tải và chia sẻ tệp đính kèm qua Share Sheet iOS.
- **Quản lý tài khoản đầy đủ:** Thêm, sửa tên/ghi chú, đổi màu nhận diện, sắp xếp thứ tự tab, đăng xuất & xóa sạch dữ liệu từng tài khoản.

---

## Cách 1 (Khuyên dùng cho Windows): Xuất file `.ipa` miễn phí bằng GitHub Actions

Vì Apple chỉ cho phép biên dịch ứng dụng iOS trên macOS/Xcode, dự án đã cấu hình sẵn workflow [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml) chạy trên **GitHub Actions (`macos-latest`)** để tự động tạo file `.ipa` mà **không cần máy Mac hay tài khoản Apple Developer trả phí**.

### Bước 1: Đẩy toàn bộ thư mục dự án lên GitHub
1. Tạo một repository mới trên [GitHub](https://github.com) (chọn **Public** để không giới hạn phút build miễn phí, hoặc **Private** với gói miễn phí hàng tháng).
2. Tải và cài **GitHub Desktop** (hoặc dùng **Git CLI**) để đẩy toàn bộ thư mục `MultiZaloIOS` lên nhánh `main` hoặc `master`.
   > **Quan trọng:** Không kéo-thả từng file qua trình duyệt web vì trình duyệt dễ bỏ sót thư mục ẩn `.github/`. Hãy dùng GitHub Desktop hoặc lệnh `git` để đảm bảo file `.github/workflows/build-ipa.yml` được đẩy lên đầy đủ.

### Bước 2: Tải file `.ipa` đã biên dịch
1. Mở repository trên GitHub → chọn tab **Actions**.
2. Chọn workflow **Build MultiZalo IPA (iOS)** đang chạy (hoặc đã hoàn thành màu xanh lá).
   - *Mẹo:* Bạn cũng có thể nhấn nút **Run workflow** trên tab Actions nếu muốn nhập một `Bundle Identifier` tùy chỉnh (mặc định là `com.multizalo.ios`).
3. Đợi khoảng **2–3 phút** cho quá trình build hoàn tất.
4. Cuộn xuống mục **Artifacts** → tải file **`MultiZalo-iOS-IPA.zip`** về máy.
5. Giải nén file `.zip` để lấy file **`MultiZalo-unsigned.ipa`**.

---

## Cách cài file `.ipa` lên iPhone / iPad (Yêu cầu iOS 17.0+)

File `MultiZalo-unsigned.ipa` là bản chưa ký chứng chỉ. Bạn có thể cài lên thiết bị iOS bằng một trong các công cụ phổ biến sau:

- **Sideloadly (trên Windows/macOS):** Cắm iPhone vào máy tính, kéo file `MultiZalo-unsigned.ipa` vào Sideloadly, nhập Apple ID miễn phí (tự gia hạn mỗi 7 ngày).
- **AltStore / SideStore:** Cài trực tiếp bằng Apple ID cá nhân (SideStore hỗ trợ tự làm mới ngay trên iPhone qua Wi-Fi).
- **TrollStore (nếu thiết bị hỗ trợ phiên bản iOS tương thích):** Cài vĩnh viễn không hết hạn 7 ngày.
- **Chứng chỉ Apple Developer (trả phí / dịch vụ ký):** Ký file `.ipa` để cài dài hạn 1 năm.

---

## Cách 2: Tự build trực tiếp bằng Xcode trên macOS

Nếu bạn đang dùng máy Mac đã cài sẵn Xcode (15/16+) và Homebrew:

```bash
brew install xcodegen
xcodegen generate
open MultiZalo.xcodeproj
```

Sau đó chọn **Signing & Capabilities** → chọn Team của bạn trong Xcode và build ra thiết bị hoặc **Product → Archive** để xuất `.ipa`.

---

## Tùy chỉnh biểu tượng ứng dụng (App Icon — Tùy chọn)

Dự án đã cấu hình sẵn catalog `AppIcon` trống để build sạch mà không lỗi. Nếu muốn đặt icon riêng cho app, bạn chỉ cần thêm một ảnh PNG vuông kích thước **`1024×1024`** (không có nền trong suốt / alpha channel) vào `MultiZalo/Resources/Assets.xcassets/AppIcon.appiconset/` và khai báo `"filename"` trong `Contents.json` của `AppIcon.appiconset`.

---

## Lưu ý về giới hạn của Zalo Web trên iOS

- **Đăng nhập:** Sử dụng mã QR hoặc đăng nhập web của `chat.zalo.me` (do chính sách của Zalo Web).
- **Thông báo đẩy:** Do iOS giới hạn tiến trình nền với `WKWebView`, ứng dụng **không nhận thông báo đẩy khi đã đóng hoàn toàn**; khi mở ứng dụng, các phiên chạy song song sẽ tự cập nhật badge tin nhắn mới.
- **Gợi ý hiển thị trên iPhone:** Mặc định app đặt mức thu phóng **80%** cho iPhone (100% cho iPad). Bạn có thể đổi nhanh mức thu phóng (70%–115%) ở nút menu `•••` góc trên bên phải hoặc xoay ngang màn hình để dùng thoải mái hơn.

# WellKept

Sổ tay bảo trì & bảo hành đồ dùng — xe cộ, thiết bị trong nhà, hóa đơn và phiếu bảo hành.
Không tài khoản, không máy chủ: mọi dữ liệu nằm ngay trên máy của bạn.

**Bản web:** https://fralcy.github.io/WellKept/

## Tính năng

- **Mốc bảo trì kế tiếp**, tự tính từ lần bảo trì gần nhất:
  - theo thời gian (ví dụ vệ sinh máy lạnh 180 ngày/lần),
  - theo chỉ số (ví dụ thay nhớt mỗi 2.000 km),
  - một lần (ngày hết hạn bảo hành).
- **Lịch sử bảo trì**: ghi ngày, chỉ số, ghi chú, ảnh hóa đơn; sửa/xóa log cũ.
- **Ảnh món đồ**: chụp hoặc chọn từ thư viện.
- **Nhắc nhở** trước hạn và đúng ngày tới hạn, giờ nhắc chỉnh trong Cài đặt; chạm vào
  thông báo mở thẳng món đồ đó. *(Chỉ trên điện thoại — bản web không gửi được thông báo
  khi đã đóng trang.)*
- **Tìm kiếm & lọc**: tìm không cần gõ dấu, lọc theo loại hoặc "Cần chú ý".
- **Sao lưu / khôi phục** toàn bộ dữ liệu + ảnh ra một file `.zip`.
- Tiếng Việt / English, 5 giao diện màu.

## Cài đặt trên Android (APK)

1. Tải file APK phù hợp với máy (đa số điện thoại hiện nay dùng `app-arm64-v8a-release.apk`).
2. Mở file trên điện thoại, cho phép "Cài đặt ứng dụng không rõ nguồn gốc" khi được hỏi.
3. Lần đầu thêm món đồ có ngày tới hạn, app sẽ xin quyền gửi thông báo — chọn **Cho phép**.

## Sao lưu & chuyển máy

Cài đặt (⚙) → **Sao lưu dữ liệu** → **Xuất file sao lưu**, lưu file `.zip` vào Drive/máy tính.
Trên máy mới: **Khôi phục từ file** → chọn file → **Thay thế** (máy mới, chưa có gì) hoặc
**Gộp** (giữ dữ liệu đang có và thêm từ file).

## Phát triển

```sh
flutter pub get                                            # tự sinh code l10n từ lib/core/l10n/*.arb
dart run build_runner build --delete-conflicting-outputs   # sinh *.g.dart (Hive adapters)
flutter analyze && flutter test
flutter run -d chrome                                      # hoặc flutter run trên emulator/thiết bị
```

- Code sinh tự động (`*.g.dart`, `lib/core/l10n/app_localizations*.dart`) không commit.
- Icon/màn hình chờ: sửa ảnh trong `assets/icon/` rồi chạy `dart run flutter_launcher_icons`
  và `dart run flutter_native_splash:create`.
- CI (`.github/workflows/ci.yml`): mọi push chạy analyze + test; push lên `main` (test xanh)
  tự deploy bản web lên GitHub Pages.

### Build APK release

```sh
flutter build apk --release --split-per-abi   # → build/app/outputs/flutter-apk/
```

APK được ký bằng khóa debug của máy build (`~/.android/debug.keystore`). Bản mới chỉ cài
đè lên bản cũ khi được build trên cùng máy (cùng khóa); đổi máy build thì chép theo file
đó, hoặc sao lưu dữ liệu trong app → gỡ → cài bản mới → khôi phục.

### Kiểm thử tay trước khi phát hành

Trên điện thoại thật, với APK release:

- [ ] Thêm món đồ có ảnh (chụp và chọn từ thư viện); ảnh hiện trên thẻ.
- [ ] Đặt giờ nhắc vài phút tới, thêm món đồ tới hạn hôm nay → nhận được thông báo.
- [ ] Chạm thông báo khi app đang mở và khi app đã tắt → mở đúng món đồ.
- [ ] Ghi log có ảnh, sửa log, xóa log; chỉ số km cập nhật đúng.
- [ ] Xuất sao lưu → gỡ app → cài lại → khôi phục → đủ món đồ, log và ảnh.
- [ ] Đổi ngôn ngữ sang English → thông báo đặt sau đó cũng bằng tiếng Anh.

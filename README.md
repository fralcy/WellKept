# WellKept

Sổ tay bảo trì & bảo hành đồ dùng (xe, thiết bị nhà, hóa đơn/bảo hành) — Flutter,
chạy Android/iOS/Web, offline-first (Hive, không backend).

- Mốc kế tiếp theo ngày, theo chỉ số (km...) hoặc một lần (hết bảo hành).
- Ảnh món đồ/hóa đơn, lưu ngay trong máy.
- Thông báo nhắc trước hạn và đúng ngày tới hạn, giờ nhắc chỉnh trong Cài đặt
  (chỉ trên điện thoại — bản web không gửi được thông báo khi đã đóng trang).
- Tiếng Việt / English.

## Chạy dự án

```sh
flutter pub get                                            # tự sinh code l10n từ lib/core/l10n/*.arb
dart run build_runner build --delete-conflicting-outputs   # sinh *.g.dart (Hive adapters)
flutter test
flutter run -d chrome   # hoặc flutter run trên emulator/thiết bị
```

Code sinh tự động (`*.g.dart`, `lib/core/l10n/app_localizations*.dart`) không commit.

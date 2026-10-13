# WellKept

Sổ tay bảo trì & bảo hành đồ dùng (xe, thiết bị nhà, hóa đơn/bảo hành) — Flutter,
chạy Android/iOS/Web, offline-first (Hive, không backend).

## Chạy dự án

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # sinh *.g.dart (Hive adapters, không commit)
flutter test
flutter run -d chrome   # hoặc flutter run trên emulator/thiết bị
```

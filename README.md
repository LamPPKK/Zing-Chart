# #zingChart

Ứng dụng bảng xếp hạng và trình phát nhạc Flutter chạy từ một codebase trên
Android, iOS, Web/PWA, Windows, macOS và Linux.

## Tính năng

- Zing Chart, tìm kiếm cục bộ theo bài hát/nghệ sĩ và thư viện yêu thích.
- Queue, previous/next, shuffle, repeat, seek và khôi phục phiên nghe cục bộ.
- Giao diện adaptive: bottom navigation trên mobile, navigation rail và panel
  Now Playing trên màn hình rộng.
- Phím tắt desktop: Space, Ctrl/Cmd+F, mũi tên, Ctrl/Cmd+mũi tên và Escape.
- Background/system media controls qua Audio Service, Linux MPRIS, Windows SMTC
  và Web Media Session khi nền tảng hỗ trợ.
- Flutter Web có manifest PWA; chỉ cache app shell và dữ liệu chart, không tải
  hoặc lưu file nhạc offline.

## Chạy proxy

Client không gọi trực tiếp Zing. Khởi động proxy Node/Docker trong thư mục
`proxy` theo hướng dẫn tại `proxy/README.md`.

```sh
cd proxy
npm ci
npm run dev
```

Hoặc build container:

```sh
docker build -t zingchart-proxy proxy
docker run --env-file proxy/.env -p 8080:8080 zingchart-proxy
```

## Chạy ứng dụng

Flutter 3.44.7 được cấu hình qua FVM.

```sh
fvm flutter pub get
fvm flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080
```

Release build bắt buộc dùng HTTPS:

```sh
fvm flutter build web --release \
  --dart-define=API_BASE_URL=https://proxy.example.com
```

Các platform build khác dùng cùng `--dart-define`. Nếu release build thiếu hoặc
sai `API_BASE_URL`, app hiển thị màn hình chẩn đoán thay vì gọi upstream.

## Kiểm tra

```sh
fvm flutter analyze
fvm flutter test
cd proxy && npm test && npm run typecheck && npm run build
```

CI trong `.github/workflows` build và lưu artifact cho từng hệ điều hành. Các
bản phát hành ký số/notarize cần secrets chứng thư tương ứng của môi trường.

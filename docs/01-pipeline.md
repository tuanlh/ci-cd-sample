# Hiểu pipeline như công việc hằng ngày

## Một thay đổi đi từ máy bạn đến staging

Giả sử bạn cần tăng giới hạn title từ 120 lên 200 ký tự. Bạn tạo branch, sửa validation, thêm test 200 được chấp nhận và 201 bị từ chối, chạy local, commit rồi mở PR. CI kiểm tra trên máy runner sạch. Đồng đội review và merge sau khi các check xanh. Main được kiểm tra lại vì kết quả tích hợp có thể khác branch. Image được đẩy lên registry, rồi staging kéo đúng digest đó về chạy.

Bạn kiểm tra deployment, gọi `/version` để đối chiếu commit, đọc log và thử hành vi mới. Nếu có lỗi lọt qua test, rollback về digest cũ, mở PR sửa lỗi và bổ sung test để lỗi đó không tái diễn. Đó là vòng làm việc điển hình; không phải ngày nào cũng sửa YAML.

## Các bước CI trong project

| Bước | Mục đích | Vì sao có thể đỏ? |
|---|---|---|
| Checkout | Lấy code đúng commit | Quyền truy cập/repo |
| Setup .NET | Chuẩn bị SDK 10 | Tải SDK lỗi hoặc version không phù hợp |
| Restore locked | Tải dependency theo lock file đã commit | Sửa package nhưng quên cập nhật lock, NuGet mất kết nối |
| Build Release | Kiểm tra biên dịch, coi warning là lỗi | Lỗi C#, nullable warning |
| Integration tests | Kiểm tra contract HTTP và nghiệp vụ | 400/404/201 sai, validation bị hỏng |
| Upload TRX | Lưu bằng chứng test, kể cả khi test thất bại | Chưa đến bước test thì chưa có report |
| Docker build | Đóng gói runtime, gắn commit vào APP_VERSION | Sai COPY, thiếu file, lỗi publish |
| Smoke image | Chạy container thật và kiểm tra HTTP | Port/runtime/entrypoint/config sai |
| Export image | Chuyển chính image đã test sang job publish | Chỉ chạy trên push main |

Test tích hợp dùng `WebApplicationFactory`: host ASP.NET chạy trong tiến trình test; mỗi test có store riêng nên không phụ thuộc thứ tự. Smoke test bổ sung kiểm tra image thật với runtime thật. Test không thể chứng minh không còn bug; chúng bảo vệ các hành vi đã mô tả.

## Build một lần, triển khai cùng đầu ra

Job `verify` build `taskapi:ci`, smoke test rồi `docker save` thành artifact. Job `publish` dùng `docker load`, tag theo SHA và push. Nó **không build lại**. Vì vậy image được xuất bản là image đã được smoke test.

Ví dụ:

```text
Commit:       3a6... (40 ký tự)
Tag:          ghcr.io/owner/repo:3a6...
Deploy ref:   ghcr.io/owner/repo@sha256:abc... (64 ký tự digest)
/version:     {"version":"3a6...","environment":"Staging"}
```

Tag là tên có thể bị gán lại. Digest nhận diện nội dung cụ thể; deployment dùng digest, không dùng `latest`. `/version` xác nhận code nào thực sự đang phục vụ request. Lưu digest từ phần Summary của job publish để rollback.

File `packages.lock.json` được commit và restore bằng `--locked-mode`. Khi chủ động thay package, sửa `.csproj`, chạy `dotnet restore CiCdSample.slnx --force-evaluate`, review lock file và commit cả hai. Base image `10.0` và action tag `@v4` vẫn có thể thay đổi: bản production nên pin digest/SHA và dùng bot cập nhật định kỳ. Lock file không có nghĩa toàn bộ build đã tái lập tuyệt đối.

## Đọc YAML

- `on`: sự kiện kích hoạt. PR chỉ kiểm tra; push vào main kiểm tra và publish.
- `jobs`: các máy runner độc lập. Không mặc định chia sẻ file hoặc image.
- `needs`: quan hệ phụ thuộc. Verify đỏ thì publish và deploy không được chạy.
- `steps`: chạy theo thứ tự trong một job. Exit code khác 0 làm step và job thất bại.
- `if`: điều kiện chạy; `always()` dành cho thu thập report/log khi có lỗi.
- `permissions`: CI chỉ đọc repo, publish được ghi packages. Không cần PAT để publish GHCR trong workflow này.
- `secrets`: thông tin nhạy cảm như SSH private key. `vars.ENABLE_STAGING`: công tắc không nhạy cảm.
- `environment: staging`: gắn deployment với secrets và quy tắc của môi trường.
- `concurrency`: hạn chế các lần deploy đè nhau. `flock` còn khóa thao tác trên máy chủ. GitHub không bảo đảm thứ tự hàng đợi; kiểm tra SHA deployment cuối khi merge liên tục.

Nếu CI đỏ, mở **step thất bại đầu tiên**, tìm thông báo lỗi cụ thể, tái hiện bằng lệnh tương ứng trên máy rồi sửa. Không xóa test hoặc đổi `continue-on-error` để làm pipeline xanh giả.

## Đọc Dockerfile

`source` chứa SDK, code và dependency. `test` chạy test và trả exit code cho Compose. `publish` tạo output Release. `final` chỉ chứa ASP.NET runtime và output publish, chạy bằng `$APP_UID` không phải root. `APP_VERSION` được gắn khi build, không bị thay bằng env lúc deploy.

Docker build mặc định chỉ xây các stage cần cho `final`, không tự chạy stage `test`. Vì thế workflow và `verify.ps1` có bước test riêng. `EXPOSE 8080` là mô tả; muốn truy cập từ host vẫn phải publish port qua Compose hoặc `docker run -p`.

## Ranh giới khi lên production

Thêm branch protection bắt buộc checks/review, pin actions theo commit, dependency và image scanning, phân quyền môi trường, quản lý secrets, quan sát lỗi/latency, backup và diễn tập phục hồi. Với database, migration phải tương thích cả bản cũ và mới khi rollout. Deploy Compose hiện tại có khoảng gián đoạn lúc thay container; nếu cần liên tục phục vụ thì học tiếp blue/green hoặc rolling deployment.

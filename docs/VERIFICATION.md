# Kết quả kiểm chứng

Ngày thực hiện: **08/11/2026**, trên Windows với Docker Desktop Linux containers.

| Hạng mục | Kết quả |
|---|---|
| .NET SDK tạm 10.0.403: restore locked | PASS |
| Build Release và test trên Windows | PASS — 7 passed, 0 failed |
| Test trong SDK Linux container | PASS — 7 passed, 0 failed |
| `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` | PASS — chạy trọn luồng test/build/start/smoke |
| HTTP health/version/create/read/complete/invalid title | PASS |
| Runtime user | PASS — uid=1654(app), không phải root |
| Runtime với read-only filesystem, tmpfs, cap-drop, no-new-privileges | PASS — smoke HTTP thành công |
| Smoke với expected version cố tình sai | PASS — phát hiện sai phiên bản và trả exit code lỗi |
| Compose local và staging config | PASS — `docker compose config --quiet` |
| Bash deploy syntax | PASS — Git Bash `bash -n deploy/deploy.sh` |
| Hai GitHub workflow | PASS — actionlint 1.7.12, không có lỗi |
| Push/publish trên GitHub/GHCR | Chưa chạy — chưa có remote repo/tài khoản được cấu hình |
| Deploy và rollback trên Linux host qua SSH | Chưa chạy — chưa có server/secrets |

API local được giữ chạy tại `http://localhost:8080`. Có thể dừng bằng `docker compose down`. Container kiểm tra hardening riêng đã được dọn. Test report nằm trong `TestResults/` và không được commit.

Ban đầu host chưa có `dotnet` trong PATH. Để kiểm chứng đã cài SDK vào **`%TEMP%\cicd-sample-tools\dotnet`**, không thêm PATH hệ thống. Docker Engine đã được khởi động. Công cụ actionlint cũng nằm ở thư mục tạm; người học không cần cài các công cụ tạm này để chạy luồng Docker trong README.

Kiểm tra cú pháp workflow không thay thế một lần chạy thật trên GitHub. Kiểm tra hardening local không thay thế kiểm tra SSH, GHCR permissions và rollback trên staging. Hoàn thành hướng dẫn `02-github-staging.md` và các bài 4–6 trong `03-practice.md` để nghiệm thu phần đó.

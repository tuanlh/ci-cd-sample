# Từ local lên GitHub rồi đến staging

## A. Tạo repo và chạy CI/CD phần registry

1. Tạo repository GitHub trống, ví dụ `ci-cd-sample`. Không tạo README trên GitHub vì local đã có. Repo public giúp làm lab thuận tiện hơn; repo private có thể chịu giới hạn phút Actions/storage theo tài khoản.
2. Trong PowerShell ở thư mục project, thay URL bằng repo của bạn:

```powershell
git init -b main
git add .
git commit -m "Add .NET CI/CD learning lab"
git remote add origin https://github.com/YOUR_USER/ci-cd-sample.git
git push -u origin main
```

Nếu Git chưa có danh tính, đặt `git config user.name "Tên bạn"` và `git config user.email "email của bạn"` trong repo rồi commit lại. Không commit SSH private key, PAT hoặc file `.env`.

3. Vào tab **Actions**, mở run **CI and delivery**. Job `Build, test and smoke` phải xanh; `Publish tested image` phải xanh; `deploy` được **skipped** khi chưa bật staging, đó là đúng cấu hình ban đầu.
4. Tải artifact `test-results`, đọc file `.trx`. Trong Summary của publish, lưu chuỗi `ghcr.io/...@sha256:...`. Vào Packages của tài khoản/repo để kiểm tra image có tag là commit SHA.

**Đạt giai đoạn này:** PR chạy kiểm tra, main xuất bản image; chưa được gọi là đã deploy staging. Máy runner bị hủy sau job; container smoke trên runner không phải một server ứng dụng lâu dài.

### Branch protection

Sau lần chạy đầu, vào **Settings → Rules → Rulesets** hoặc **Branches → Branch protection** tùy giao diện/quyền tài khoản. Bảo vệ `main`, yêu cầu PR và status check `Build, test and smoke`; bật review nếu có người review. Nếu dùng một mình, tránh bật yêu cầu review khiến không ai có thể duyệt PR. Khả năng áp dụng rules phụ thuộc loại repo và gói tài khoản.

Workflow chạy khi PR nhắm `main`. Tạo branch và PR để thử:

```powershell
git switch -c feature/title-limit
# Sửa code và test; chạy verify trước khi commit
git add .
git commit -m "Increase title limit with regression tests"
git push -u origin feature/title-limit
```

Mở PR trên GitHub, xem check xanh, review diff rồi merge. Đừng đổi tên nhánh chính nếu chưa sửa các điều kiện `main` trong workflow.

## B. Chuẩn bị staging Linux

Cần một máy Linux x86_64 của bạn (VM/VPS), truy cập SSH được từ GitHub-hosted runner, có Bash, `curl`, `flock`, Docker Engine và Docker Compose v2. Image build trên runner `ubuntu-latest` là Linux amd64; ARM host cần thêm quy trình build/test đa kiến trúc.

Chưa có server thì hoàn thành phần A và các bài local trước. Workflow staging đã có sẵn, không thể triển khai thật khi chưa có host và thông tin SSH.

Trên máy chủ, dùng user riêng ví dụ `deploy`, có quyền chạy Docker và thư mục home ghi được. Quyền dùng Docker tương đương quyền quản trị host; chỉ cấp cho tài khoản triển khai đáng tin. Kiểm tra bằng chính user đó:

```bash
docker version
docker compose version
curl --version
flock --version
mkdir -p ~/cicd-taskapi
```

Cài Docker theo [hướng dẫn chính thức cho Linux](https://docs.docker.com/engine/install/). Không chạy lệnh cài Ubuntu trên Windows PowerShell.

### SSH key và xác thực host

Trên máy bạn:

```powershell
ssh-keygen -t ed25519 -f "$HOME/.ssh/cicd_staging" -C "github-actions-staging"
```

Dùng key chuyên cho lab; workflow hiện tại không xử lý key có passphrase. Đưa nội dung file **`.pub`** vào `~/.ssh/authorized_keys` của user deploy trên server. File không đuôi `.pub` là private key, chỉ đưa vào GitHub secret. Kiểm tra:

```powershell
ssh -i "$HOME/.ssh/cicd_staging" deploy@YOUR_SERVER
```

Đối chiếu fingerprint host với thông tin đáng tin từ console máy chủ. Lấy dòng known_hosts bằng `ssh-keyscan -H YOUR_SERVER`, nhưng phải đối chiếu fingerprint trước khi tin kết quả; không vô hiệu hóa `StrictHostKeyChecking`. Workflow mẫu dùng port SSH 22.

### Cho server quyền pull GHCR

Nếu package public, server có thể pull ẩn danh. Với package private, đăng nhập **một lần trên server bằng user deploy** bằng PAT có quyền `read:packages` và tài khoản được phép đọc package:

```bash
read -rsp 'GHCR read token: ' GHCR_TOKEN; echo
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
unset GHCR_TOKEN
```

Token không đặt trong YAML hoặc tham số lệnh. Nếu organization dùng SSO, token có thể cần cấp quyền SSO. `GITHUB_TOKEN` trong job publish không tự làm server đăng nhập được. Docker lưu thông tin đăng nhập theo user; login bằng root không giúp user deploy pull được.

## C. Cấu hình GitHub Environment

Tạo **Settings → Environments → staging**. Tạo environment secrets:

| Secret | Nội dung |
|---|---|
| `STAGING_HOST` | IP hoặc DNS của server, không có `https://` |
| `STAGING_USER` | SSH user, ví dụ `deploy` |
| `STAGING_SSH_KEY` | Toàn bộ private key, giữ đủ dòng BEGIN/END |
| `STAGING_KNOWN_HOSTS` | Dòng known_hosts đã xác thực, khớp host trên |

Có thể yêu cầu reviewer cho environment nếu gói tài khoản hỗ trợ. Nếu có cổng duyệt, workflow sẽ chờ tại bước deployment. Trong **Settings → Secrets and variables → Actions → Variables**, tạo **repository variable** `ENABLE_STAGING` với giá trị `true`. Không chỉ tạo biến này ở environment: điều kiện gọi job được đánh giá trước khi vào environment.

Merge một PR mới hoặc chạy lại toàn bộ run main đã thành công để publish và deploy. Deploy chỉ chạy từ `main`. Với secrets môi trường, reusable workflow vẫn dùng `environment: staging` ở job đích.

## D. Kiểm chứng deployment

1. Actions: verify, publish và deploy đều xanh.
2. Log deploy có `PASS: deployed ... commit ...`.
3. SSH vào server và kiểm tra:

```bash
cd ~/cicd-taskapi
export IMAGE_REF=$(cat current-image.txt)
docker compose -p taskapi-staging -f compose.yaml ps
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/version
docker compose -p taskapi-staging -f compose.yaml logs --tail 50 api
```

`/version` phải đúng **40 ký tự SHA** của commit được deploy và environment phải là `Staging`. `current-image.txt` phải khớp digest Summary publish. Muốn thử đầy đủ từ máy Windows, mở tunnel ở terminal riêng:

```powershell
ssh -i "$HOME/.ssh/cicd_staging" -L 18080:127.0.0.1:8080 deploy@YOUR_SERVER
```

Rồi terminal khác:

```powershell
.\scripts\smoke.ps1 -BaseUrl http://localhost:18080 -ExpectedVersion FULL_COMMIT_SHA
```

Thay `FULL_COMMIT_SHA` bằng SHA thật, không dùng SHA rút gọn. Cổng 18080 trên máy bạn tránh đụng API local 8080. Đóng tunnel bằng `exit`.

## E. Rollback có chủ đích

Vào **Actions → Deploy staging or rollback → Run workflow**, chọn branch `main`. Điền:

- `image_ref`: digest của một lần publish cũ đã thành công.
- `expected_version`: SHA của commit đã tạo image cũ đó.

Chạy workflow, duyệt environment nếu có, kiểm tra `/version` đã quay lại SHA cũ. Đây là thao tác đổi bản đang chạy; lịch sử Git không bị sửa. Sửa lỗi trên branch mới và merge để tiến về phía trước. Không chạy lại run CI cũ chỉ để rollback vì có thể build lại dependency/base image khác.

### Tự phục hồi khi deploy lỗi

Script lưu image đang chạy, pull image mới **trước** khi thay container, đợi tối đa 30 vòng health/version. Nếu start hoặc kiểm tra thất bại, nó in log và chạy lại image cũ, rồi trả exit code 1 để Actions đỏ. Lần deploy đầu chưa có image cũ thì dừng bản lỗi. Pull lỗi xảy ra trước khi thay container nên bản đang chạy được giữ nguyên.

Sau phục hồi, **người vận hành vẫn phải kiểm tra health và version của bản cũ**; thông báo restored không chứng minh mọi chức năng đều đã phục hồi. `current-image.txt` chỉ được cập nhật sau deploy thành công. Không xóa image cũ trên host hoặc registry khi còn cần rollback. Không có rollback dữ liệu vì lab chưa có database.

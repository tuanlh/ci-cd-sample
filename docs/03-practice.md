# Bài thực hành và tiêu chí đạt

Làm theo thứ tự. Mỗi bài lưu lại commit SHA, log hoặc ảnh Actions và kết quả HTTP để tự chứng minh, thay vì chỉ nhìn dấu tích xanh.

## Bài 1 — Chạy và quan sát

Chạy `scripts/verify.ps1`, gọi health/version/tasks, đọc `docker compose logs api`. Mở `TestResults/*.trx`. Giải thích được vì sao API không cần SDK trên host nhưng vẫn build được.

**Đạt:** 7 test pass, smoke pass, version local; chỉ ra stage SDK và stage runtime trong Dockerfile.

## Bài 2 — Tận mắt thấy test bắt lỗi

Trong `Program.cs`, cố tình đổi `Results.Created(...)` thành `Results.Ok(task)` ở endpoint POST. Không đổi test. Chạy:

```powershell
docker compose --profile test run --build --rm tests
$LASTEXITCODE
```

**Đạt:** test `Task_can_be_created_read_and_completed` báo expected Created, actual OK và exit code khác 0. Nếu thử bằng PR, job verify đỏ, publish/deploy không chạy. Khôi phục `Results.Created`, chạy lại để xanh. Không merge thay đổi cố tình lỗi vào main.

## Bài 3 — Chuyển một yêu cầu thành PR

Tăng giới hạn title 120 → 200, cập nhật message validation và test. Thêm test title dài 200 được chấp nhận, đổi test quá dài thành 201 bị từ chối. Viết test trước rồi chạy để thấy đỏ, sửa code, chạy lại để thấy xanh.

**Đạt:** PR có code và test phù hợp, Actions xanh; publish chưa chạy trên PR. Sau merge, main có image tag SHA mới. Số test tăng là bình thường; mốc 7 chỉ áp dụng project ban đầu.

## Bài 4 — Truy vết bản phát hành

Mở Summary publish, ghi lại digest và SHA. Khi đã có staging, gọi `/version` qua SSH tunnel.

**Đạt:** đối chiếu được commit → Actions run → image digest → bản đang chạy. Giải thích vì sao `latest` không đủ để xác định bản phát hành.

## Bài 5 — Deploy và rollback

Deploy hai commit hợp lệ A rồi B; ghi lại digest và SHA của cả hai. Chạy workflow thủ công với digest/SHA A. Kiểm tra `/version` trở lại A, rồi chạy lại smoke test.

**Đạt:** workflow rollback xanh, API trả SHA A, smoke pass. Hiểu rằng task trong RAM mất khi thay container. Không dùng dữ liệu quan trọng trong bài này.

## Bài 6 — Thử đường phục hồi khi kiểm tra lỗi

Chỉ thực hiện trên staging lab. Khi A đang chạy tốt, chạy workflow thủ công bằng digest B hợp lệ nhưng `expected_version` là 40 ký tự SHA khác B, ví dụ `0000000000000000000000000000000000000000`. Sau thời gian chờ, kiểm tra phiên bản sẽ thất bại và script phục hồi A.

**Đạt:** Actions đỏ, log báo verification failed và restored previous image; gọi `/health`, `/version` xác nhận A đang hoạt động, chạy smoke với SHA A thành công. Workflow đỏ là kết quả mong muốn vì deployment B đã không đạt yêu cầu. Bài này kiểm chứng nhánh rollback do version mismatch, chưa mô phỏng crash hay lỗi DB.

## Bảng nghiệm thu

| Mức | Điều kiện đạt |
|---|---|
| Local | Build được, 7 test ban đầu pass, smoke HTTP pass |
| CI | PR tốt xanh, PR cố tình lỗi đỏ; check bắt buộc chặn merge |
| Delivery | Main đạt mới publish; digest có thật trong GHCR; report TRX tải được |
| Deployment | Server chạy đúng digest/SHA; health và smoke pass |
| Recovery | Rollback về bản cũ và tự kiểm tra lại thành công |
| Hiểu quy trình | Giải thích CI vs delivery vs deployment, runner vs server, tag vs digest |

## Xử lý lỗi thường gặp

| Triệu chứng | Kiểm tra và cách xử lý |
|---|---|
| Cannot connect to Docker daemon / named pipe | Mở Docker Desktop, đợi Engine sẵn sàng, dùng Linux containers; chạy `docker info` |
| `dotnet` không nhận diện | Dùng luồng Docker, hoặc cài .NET 10 SDK và mở terminal mới |
| Cổng 8080 đã dùng | Dừng API trực tiếp/container khác; hoặc đổi local mapping thành `127.0.0.1:18080:8080` và smoke `-BaseUrl http://localhost:18080` |
| NuGet/network restore lỗi | Kiểm tra Internet, proxy, DNS trong Docker; không bỏ `--locked-mode` chỉ để che lỗi package |
| NU1004 / lock không khớp | Nếu chủ động sửa package: restore `--force-evaluate`, review và commit lock mới |
| Docker copy thiếu lock file | Chạy restore sinh lock, commit `packages.lock.json`; kiểm tra build context là gốc repo |
| PowerShell không cho chạy script | Dùng lệnh process-scoped trong README, không cần sửa policy toàn máy |
| Health xanh nhưng version sai | Kiểm tra đúng port/host, image digest và commit; health không xác nhận phiên bản |
| GHCR push 403 | Kiểm tra Actions/package policies, `packages: write`, package cũ có liên kết/quyền với repo không |
| Server pull unauthorized | Login GHCR bằng đúng SSH user với read token hoặc đặt package public |
| SSH Permission denied | Kiểm tra đúng private/public key, user, `authorized_keys` và quyền file trên server |
| Host key verification failed | Đối chiếu lại fingerprint, cập nhật known_hosts secret khi đã xác minh thay đổi host |
| SSH timeout | Kiểm tra firewall/network và host có cho GitHub runner truy cập port 22 không |
| Deploy skipped | Kiểm tra push main, job publish, repository variable `ENABLE_STAGING=true` |
| Waiting for review | Environment staging có cổng duyệt; người có quyền cần duyệt deployment |
| Container Up nhưng smoke đỏ | Đọc log API, health/version/body HTTP, port mapping; Up chỉ xác nhận process đang chạy |

## Tự kiểm tra hiểu biết

1. Vì sao không chạy `dotnet publish` lại trên server staging?
2. Vì sao PR không được dùng SSH secrets để deploy?
3. Vì sao cần chạy CI lại sau merge?
4. Nếu image pull thất bại thì container cũ có bị thay không?
5. Nếu test xanh nhưng Docker entrypoint sai thì bước nào bắt được?
6. Nếu thêm database, vì sao rollback image chưa chắc phục hồi ứng dụng?

Đáp án: (1) triển khai cùng artifact đã kiểm tra; (2) code PR chưa được tin cậy và chưa merge; (3) main là kết quả tích hợp mới; (4) không, pull nằm trước bước thay; (5) smoke container; (6) schema/dữ liệu có thể đã thay đổi và không tương thích bản cũ.

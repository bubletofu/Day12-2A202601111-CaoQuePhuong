# Thông Tin Deploy — Checkpoint 5

> File này được điền đầy đủ thông tin deployment cho Checkpoint 5.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Cao Que Phuong |
| Mã học viên | 2A202601111 |
| Repo | https://github.com/bubletofu/Day12-2A202601111-CaoQuePhuong |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-2a202601111.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Redis add-on của Railway |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i https://day12-2a202601111.up.railway.app/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i https://day12-2a202601111.up.railway.app/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST https://day12-2a202601111.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST https://day12-2a202601111.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST https://day12-2a202601111.up.railway.app/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```json
HTTP/1.1 200 OK
content-type: application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}

HTTP/1.1 200 OK
content-type: application/json
{"status":"ready","redis":true}

HTTP/1.1 401 Unauthorized
content-type: application/json
{"detail":"invalid or missing API key"}
```

## Ảnh Chụp Màn Hình

Đã lưu ảnh chụp màn hình trong thư mục `screenshots/`:

- `screenshots/dashboard.jpg` — trang quản lý service trên Railway

## GitHub Actions CI/CD

The workflow in `.github/workflows/ci.yml` runs tests and builds the Docker
image for every push and pull request. Only a successful push to `main`
deploys to Railway and runs a `/health` smoke test.

Configure these values in the repository under **Settings -> Secrets and
variables -> Actions**:

| Type | Name | Value |
|------|------|-------|
| Secret | `RAILWAY_TOKEN` | Railway project token |
| Variable | `RAILWAY_SERVICE` | `day12-agent` |
| Variable | `PUBLIC_URL` | `https://day12-2a202601111.up.railway.app` |

The token is referenced only as `${{ secrets.RAILWAY_TOKEN }}` and is never
stored in the repository.

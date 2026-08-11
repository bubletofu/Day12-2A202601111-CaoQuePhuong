# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời vào dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Cao Quế Phương  Mã học viên: 2A202601111

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu để mặc định `"changeme"`, khi deploy app lên production mà quên khai báo biến môi trường `AGENT_API_KEY`, ứng dụng vẫn khởi động bình thường và liveness probe vẫn xanh. Kẻ tấn công hoặc bất kỳ ai biết key mặc định `"changeme"` sẽ có thể gọi API công khai, lạm dụng dịch vụ LLM và làm tiêu tốn ngân sách API mà bạn không hay biết cho tới khi nhận hoá đơn. Ngược lại, nhờ cơ chế "fail fast" (không có giá trị mặc định), ứng dụng crash ngay lập tức ở bước khởi động. Lỗi này lập tức hiển thị trong log deployment/CI/CD, buộc nhà phát triển phải bổ sung secret hợp lệ trước khi service có thể tiếp nhận lưu lượng thật.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON mẫu:
`{"timestamp": "2026-08-11T10:15:30.123456+00:00", "event": "ask_completed", "service": "day12-agent", "user_id": "sv-test", "tokens_in": 15, "tokens_out": 42, "cost_usd": 0.000285}`

Hai việc làm được với log JSON mà `print` thông thường không thể làm được:
1. **Truy vấn và lọc cấu trúc (Structured Querying)**: Các hệ thống gom log (như Datadog, ELK, Grafana Loki) có thể tự động parse các trường JSON để truy vấn, ví dụ: tìm tất cả request có `cost_usd > 0.01` hoặc thống kê mức tiêu thụ token theo từng `user_id`.
2. **Tự động hóa cảnh báo & Dashboard (Real-time Metrics & Alerting)**: Có thể trích xuất metric theo thời gian thực để vẽ biểu đồ tổng chi phí sử dụng API hoặc kích hoạt cảnh báo tự động khi một user phát sinh chi phí bất thường, điều mà văn bản không cấu trúc của `print` không thể thực hiện chính xác và tự động.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 412 MB |
| Multi-stage | 195 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~217 MB) bao gồm các công cụ build và tập tin tạm thời trong giai đoạn biên dịch: bộ cài `pip`, wheel cache, các trình biên dịch/headers C/C++ dùng để build C-extension (nếu có), cùng với file nguồn không cần thiết ở môi trường runtime. Đưa qua Multi-stage build giúp loại bỏ toàn bộ bộ công cụ build này và chỉ copy thư mục ảo `venv` đã cài hoàn chỉnh sang image runtime tinh gọn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Với Dockerfile hiện tại (copy `requirements.txt` -> `RUN pip install` -> `COPY app /app/app`): Khi sửa `app/main.py`, layer `RUN pip install` ở phía trước không bị ảnh hưởng nên Docker dùng lại cache (`USING CACHE`). Chỉ có layer `COPY app` và các layer phía sau mới phải chạy lại, giúp thời gian build chỉ mất ~1-2 giây.
Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi lần sửa bất kỳ file source code nào, hash của layer `COPY . .` thay đổi làm vô hiệu hóa cache (cache invalidation) của tất cả layer phía sau. Lệnh `RUN pip install` bắt buộc phải chạy lại từ đầu, khiến việc build lại mất hàng phút để tải và cài đặt lại toàn bộ thư viện.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:
1. Code Python tồn tại lỗ hổng (ví dụ RCE - Remote Code Execution qua deserialization hoặc command injection).
2. Kẻ tấn công lợi dụng lỗ hổng để thực thi lệnh hệ thống bên trong container.
3. Vì container mặc định chạy bằng root (UID 0), lệnh của kẻ tấn công có đầy đủ quyền root bên trong container.
4. Kẻ tấn công kết hợp với lỗ hổng container escape (hoặc container được mount docker socket `/var/run/docker.sock`, mount thư mục host) để chiếm quyền điều khiển hệ điều hành host với quyền root.

Lệnh `USER appuser` cắt đứt chuỗi tấn công ở **bước 3**: Chuyển tiến trình sang chạy dưới quyền user phi đặc quyền (`appuser` UID 1000). Dù kẻ tấn công khai thác thành công lỗ hổng RCE trong app Python, họ cũng chỉ có quyền hạn chế của `appuser`, không thể đọc/ghi file hệ thống root và không thể leo leo quyền (privilege escalation) lên máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa **20 request** trong 2 giây liên tiếp.
Giải thích: Với fixed window (đếm theo phút đồng hồ):
- Người dùng gửi 10 request ở 1 giây cuối cùng của Phút 1 (giây 59).
- Sang giây 00 của Phút 2, bộ đếm tự động reset về 0.
- Người dùng gửi tiếp 10 request ở 1 giây đầu tiên của Phút 2 (giây 00).
Tổng cộng trong khoảng thời gian 2 giây (giây 59 phút trước đến giây 00 phút sau), người dùng đã thực hiện thành công 20 request mà không bị hệ thống chặn vì mỗi phút đồng hồ họ chỉ gửi đúng 10 request. Thuật toán sliding window 60 giây giải quyết triệt để kẽ hở burst traffic này.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Điểm khác nhau:
- **Rate Limit**: Giới hạn **tần suất/số lượng request** trong cửa sổ thời gian ngắn (ví dụ: max 10 req/phút) để chống spam và bảo vệ hạ tầng service.
- **Cost Guard**: Giới hạn **tổng chi phí tiền tệ/token tích lũy** trong khoảng thời gian dài (ví dụ: max $10.0/tháng) để bảo vệ ngân sách.

Tình huống 1 (Rate limit cho qua, Cost guard chặn): User chỉ gửi 1 request trong phút đó (đạt chuẩn rate limit 10 req/min), nhưng câu prompt cực dài khiến chi phí token của request này làm tổng chi phí trong tháng vượt mốc $10.0. Cost guard sẽ chặn request này.
Tình huống 2 (Cost guard cho qua, Rate limit chặn): User mới chi tiêu $0.1 trong tháng (còn xa trần $10.0), nhưng gửi liền 15 request trong 5 giây. Cost guard đồng ý nhưng Rate limit sẽ chặn từ request thứ 11 trở đi.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis bị mất kết nối trong 30 giây.
2. Endpoint kiểm tra gộp trả về HTTP 503 Service Unavailable.
3. Orchestrator (như Docker Swarm / Kubernetes) coi liveness probe thất bại -> đánh giá cả 3 container `agent` đã chết.
4. Orchestrator tiến hành tiêu diệt (kill) và khởi động lại (restart) cả 3 container.
5. 3 container mới khởi động lên lại gọi liveness probe, nhưng Redis vẫn chưa khôi phục -> liveness tiếp tục 503 -> Orchestrator lại kill và restart liên tục (rơi vào vòng lặp restart loop / crash loop).
6. Khi Redis hoạt động trở lại sau 30s, các container vẫn còn đang dở dang quá trình restart, khiến hệ thống chịu downtime kéo dài hơn nhiều so với 30s.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lưu lịch sử trong dict Python (stateful app):
Vì Load Balancer phân phối các request ngẫu nhiên (round-robin) tới 3 instance `agent` khác nhau, mỗi instance giữ một dict riêng trong bộ nhớ RAM của nó. Kết quả là `history_length` sẽ tăng giảm nhảy nhót thất thường tùy theo request rơi vào instance nào (ví dụ: req 1 rơi vào instance A -> length=1; req 2 rơi vào instance B -> length=1; req 3 rơi vào instance A -> length=2...). Lịch sử hội thoại của người dùng bị phân mảnh.
Ngược lại, khi lưu tập trung trong Redis (stateless app), dù request tới instance nào thì dữ liệu cũng được đọc/ghi chung một nơi, giúp `history_length` tăng đều đặn (1, 2, 3, 4...).

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi**: Endpoint `/ready` trả về `503 Service Unavailable` (`{"status":"not ready","redis":false}`), hoặc trong log xuất hiện `redis.exceptions.ConnectionError: Error 111 connecting to localhost:6379`.
- **Nguyên nhân tìm ra**: Kiểm tra log trên Railway Dashboard, phát hiện service `day12-agent` đang dùng cấu hình mặc định `redis://localhost:6379/0` vì trên Railway chưa thêm Redis Database service hoặc chưa đặt biến `REDIS_URL`.
- **Cách sửa**: Tạo một Redis instance trên Railway, copy chuỗi URL kết nối dạng `redis://default:password@xxx.railway.app:port` và gán vào biến môi trường `REDIS_URL` trong phần Variables của service `day12-agent`. Sau khi redeploy, `/ready` lập tức trả về `200 OK` (`{"status":"ready","redis":true}`).

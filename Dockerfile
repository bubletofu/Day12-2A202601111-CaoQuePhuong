# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runner

WORKDIR /app

RUN useradd -m -u 1000 appuser

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

COPY app /app/app
COPY utils /app/utils

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

ENV PORT=8000

HEALTHCHECK --interval=10s --timeout=5s --start-period=2s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:' + str(os.environ.get('PORT', 8000)) + '/health')" || exit 0

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]

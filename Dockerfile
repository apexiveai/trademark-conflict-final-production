# Build the React single-page application.
FROM node:22-alpine AS frontend-build

WORKDIR /build
COPY frontend/package*.json ./
RUN npm ci

COPY frontend ./
# A single container serves the UI and API, so the browser can call /api directly.
ARG VITE_API_URL=/
ENV VITE_API_URL=${VITE_API_URL}
RUN npm run build


# Install the Python API and its native runtime dependencies.
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8020

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    tesseract-ocr \
    imagemagick \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY backend/app ./app
RUN mkdir -p /app/data /var/cache/nginx /var/run/nginx \
    && python -m compileall -q /app/app

COPY --from=frontend-build /build/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

VOLUME ["/app/data"]
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8080/health')"

CMD ["sh", "-c", "uvicorn app.main:app --host 127.0.0.1 --port ${PORT} --workers 1 & exec nginx -g 'daemon off;'"]

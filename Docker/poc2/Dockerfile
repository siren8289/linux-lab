FROM python:3.12-slim

WORKDIR /app
COPY app.py .

RUN useradd --uid 10001 --create-home appuser \
    && mkdir -p /data \
    && chown appuser:appuser /data

USER appuser
EXPOSE 8080

CMD ["python", "-u", "app.py"]

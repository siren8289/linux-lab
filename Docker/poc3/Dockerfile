FROM python:3.12-slim

WORKDIR /app
COPY worker.py .

RUN useradd --uid 10001 --create-home appuser

USER appuser

CMD ["python", "-u", "worker.py"]

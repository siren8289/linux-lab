FROM python:3.12-slim

WORKDIR /app

COPY app.py .

RUN useradd --create-home --uid 10001 appuser

USER appuser

EXPOSE 8080

CMD ["python", "-u", "app.py"]

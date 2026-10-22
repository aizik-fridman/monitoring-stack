FROM python:3.13.5-slim

WORKDIR /app
COPY receiver.py /app/receiver.py
USER 10001:10001
EXPOSE 8080
CMD ["python", "/app/receiver.py"]

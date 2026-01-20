FROM python:3.11-slim

WORKDIR /app

COPY services/meshtastic-normalizer/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY farmstack /app/farmstack
COPY services/meshtastic-normalizer /app/service
COPY contracts /app/contracts
COPY configs /app/configs

ENV PYTHONPATH=/app

CMD ["python", "/app/service/main.py"]
FROM aiogram/telegram-bot-api:latest

RUN apk add --no-cache python3 py3-pip wget

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt

COPY main.py /app/main.py
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

ENV TELEGRAM_LOCAL_PORT=8081
ENV PYTHONUNBUFFERED=1

EXPOSE 10000

ENTRYPOINT ["/app/start.sh"]

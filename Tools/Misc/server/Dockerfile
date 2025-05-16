FROM python:3.12-alpine

WORKDIR /usr/src/securethenetwork

RUN apt-get update && apt-get install -y socat && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY . .

RUN addgroup -S northland && adduser -S northland -G northland
RUN chown -R northland:northland /usr/src/physical
USER northland

EXPOSE 1337

ENV FLAG=INSERT-FLAG-HERE

CMD ["socat", "-dd", "TCP-LISTEN:1337,fork,reuseaddr", "EXEC:python3 server.py"]

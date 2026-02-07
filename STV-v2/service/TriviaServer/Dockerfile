FROM python:3.12-alpine
WORKDIR /usr/src/physical

RUN apk update && apk add --no-cache socat && apk upgrade && apk cache clean

COPY . .

RUN addgroup -S northland && adduser -S northland -G northland
RUN chown -R northland:northland /usr/src/physical
USER northland

EXPOSE 1337

ENV FLAG=YBN{019aecc9843873b689b96225c1299939}

CMD ["socat", "-dd", "TCP-LISTEN:1337,fork,reuseaddr", "EXEC:python3 server.py"]

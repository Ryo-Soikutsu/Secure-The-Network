FROM python:3.12-alpine

WORKDIR /usr/src/securethenetwork

RUN apt-get update && apt-get install -y socat && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY . .

RUN addgroup -S physgrp && adduser -S physuser -G physgrp
RUN chown -R physuser:physgrp /usr/src/physical
USER physuser

EXPOSE 1337

ENV FLAG=NYP{N0rth_Po1E_53cUr3d!!}

CMD ["socat", "-dd", "TCP-LISTEN:1337,fork,reuseaddr", "EXEC:python3 server.py"]

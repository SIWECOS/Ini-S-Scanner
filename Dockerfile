FROM alpine:latest

RUN apk add --no-cache \
    openssl \
    perl \
    curl \
    gcc \
    libc-dev \
    libressl-dev \
    make \
    perl-dev \
    wget \
    zlib-dev \
  && curl -L https://cpanmin.us \
    | perl - -M https://cpan.metacpan.org \
      -n DBI \
      -n DBD::SQLite \
      -n Mojolicious \
      -n Minion \
      -n Minion::Backend::SQLite \
      -n App::Prove \
      -n IO::Socket::SSL \
      -n Net::IDN::Encode \
      -n Text::CSV \
      -n Storable \
  && apk del \
    zlib-dev \
    wget \
    perl-dev \
    make \
    libressl \
    libc-dev \
    gcc \
    curl \
  && rm -rf /root/.cpanm/* /usr/local/share/man

COPY blacklist_checker/ /app/blacklist_checker/

RUN ln -s /app/blacklist_checker/script/blacklist_checker /usr/local/bin/blacklist

EXPOSE 8080

CMD [ "/app/blacklist_checker/script/start" ]

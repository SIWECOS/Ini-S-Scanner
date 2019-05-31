FROM alpine:latest

RUN apk add --no-cache \
    curl \
    gcc \
    libc-dev \
    libressl-dev \
    make \
    openssl \
    perl \
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
  && rm -rf /root/.cpanm/* /usr/local/share/man/*

WORKDIR /home

ADD blacklist_checker /home/

ENV PATH="/home/blacklist_checker/script:$PATH"
ENV BLACKLIST="/home/storage/blacklists.sqlite"

EXPOSE 8080

CMD [ "start" ]
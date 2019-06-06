FROM alpine:latest

# Install all requirements
RUN  apk add --no-cache \
     openssl            \
     perl               \
     curl               \
     gcc                \
     libc-dev           \
     libressl-dev       \
     make               \
     perl-dev           \
     wget               \
     zlib-dev           \
  && curl -L https://cpanmin.us \
     | perl - -M https://cpan.metacpan.org \
       -n DBI                              \
       -n DBD::SQLite                      \
       -n Mojolicious                      \
       -n Minion                           \
       -n Minion::Backend::SQLite          \
       -n App::Prove                       \
       -n IO::Socket::SSL                  \
       -n Net::IDN::Encode                 \
       -n Text::CSV                        \
       -n Storable                         \
  && apk del  \
     zlib-dev \
     wget     \
     perl-dev \
     make     \
     libressl \
     libc-dev \
     gcc      \
     curl     \
  && rm -rf /root/.cpanm/* /usr/local/share/man

# Copy the scanner code
COPY blacklist_checker/ /app/blacklist_checker/

# Create convenience link and create storage folder
RUN  ln -s /app/blacklist_checker/script/blacklist_checker /usr/local/bin/blacklist \
  && mkdir /storage

# Do not run as root but as user "mojo"
RUN  addgroup mojo \
  && adduser -D -h /home/mojo -s /bin/sh -G mojo mojo \
  && chown -R mojo:mojo /app/blacklist_checker /storage
WORKDIR /home/mojo
USER mojo

# Please request an api token at https://data.phishtank.com/
# if you plan to use regularly
ENV PHISHTANK_API=
ENV MOJO_MODE=production

# We're using port 8080.
# Check /app/blacklist_checker/etc/blacklist_checker.conf to configure another port
EXPOSE 8080

CMD [ "/app/blacklist_checker/script/start" ]

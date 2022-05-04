ARG DEB_VERSION=11

FROM debian:${DEB_VERSION}

COPY entrypoint.sh /

# Ferramentas para ajudar no debug
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends \
#         net-tools iputils-ping nano postgresql-client-13

RUN apt-get update \
    && apt-get install -y --no-install-recommends "pgpool2=4.1.4-3" procps \
    && rm -fr /var/lib/apt/lists/* \
    && chmod +x /entrypoint.sh

USER postgres

CMD [ "/entrypoint.sh" ]

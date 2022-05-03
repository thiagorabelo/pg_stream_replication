ARG DEB_VERSION=11

FROM debian:${DEB_VERSION}

# Ferramentas para ajudar no debug
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends \
#         net-tools iputils-ping nano postgresql-client-13

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgpool2 \
    && rm -fr /var/lib/apt/lists/*

USER postgres

CMD pgpool -n
# CMD pgpool -n -d

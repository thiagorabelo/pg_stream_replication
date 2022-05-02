# Debian 11, codinome bullseye
FROM postgres:14

ENV PAGER="less -S" \
    LANG="pt_BR.UTF-8" \
    TZ="America/Fortaleza"

RUN localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias pt_BR.UTF-8 \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get update && apt-get install less rsync -y \
    && rm -fr /var/lib/apt/lists/*

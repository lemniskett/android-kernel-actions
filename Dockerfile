FROM docker.io/library/ubuntu:focal
ENV DEBIAN_FRONTEND noninteractive
RUN set -ex; \
    apt update; \
    apt upgrade -y;
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
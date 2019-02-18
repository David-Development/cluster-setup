FROM openjdk:8u151-jre-alpine

WORKDIR /src

RUN apk add --no-cache \
    docker \
    curl \
    git \
    bash \
    openssh \
    py-pip \
    python \
    python-dev \
    ruby \
    ruby-bundler \
    ruby-dev \
    ruby-json

RUN pip install --upgrade pip && \
    pip install python-dateutil

ENV DIGDAG_VERSION 0.9.31
RUN curl -o /bin/digdag -L "https://dl.digdag.io/digdag-${DIGDAG_VERSION}" && \
    chmod +x /bin/digdag


COPY digdag-server.conf /digdag/config/digdag-server.conf

ENTRYPOINT [ "java", "-jar", "/bin/digdag" ]

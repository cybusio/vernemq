FROM debian:bullseye-slim AS builder

RUN apt-get update && apt-get -y install apt-utils
RUN apt-get -y install bash build-essential git \
  procps openssl libsnappy-dev libssl-dev net-tools \
  curl erlang

WORKDIR /app
COPY . /app
RUN make rel

# #############################
# Runtime container

FROM debian:bullseye-slim
RUN apt-get update && \
    apt-get -y install bash procps openssl iproute2 libsnappy1v5 net-tools && \
    rm -rf /var/lib/apt/lists/* && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 --system --ingroup vernemq --home /vernemq --disabled-password vernemq

WORKDIR /vernemq

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="1.12.5-cybus"

COPY --from=builder --chown=10000:10000 /app/_build/default/rel/vernemq /vernemq
COPY --chown=10000:10000 docker-vernemq/files/vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 docker-vernemq/files/vm.args /vernemq/etc/vm.args
RUN chown -R 10000:10000 /vernemq && \
    ln -s /vernemq/etc /etc/vernemq && \
    ln -s /vernemq/data /var/lib/vernemq && \
    ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
       9100 9101 9102 9103 9104 9105 9106 9107 9108 9109


VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]
#VOLUME ["/vernemq/data"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq
CMD ["start_vernemq"]

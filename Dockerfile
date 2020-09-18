FROM crystallang/crystal:0.35.1 as build

COPY . /src
WORKDIR /src
RUN make all

FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y libyaml-0-2 libssl1.1 libevent-2.1-6 ca-certificates
COPY --from=build /src/matrix-architect /app/matrix-architect
WORKDIR /app

ENTRYPOINT ["/app/matrix-architect"]

# The image for building
FROM phusion/baseimage:focal-1.2.0 as build
ENV LANG=en_US.UTF-8

# Install dependencies
RUN \
    apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get update && \
    apt-get install -y \
      g++ \
      autoconf \
      cmake \
      git \
      libbz2-dev \
      libcurl4-openssl-dev \
      libssl-dev \
      libncurses-dev \
      libboost-thread-dev \
      libboost-iostreams-dev \
      libboost-date-time-dev \
      libboost-system-dev \
      libboost-filesystem-dev \
      libboost-program-options-dev \
      libboost-chrono-dev \
      libboost-test-dev \
      libboost-context-dev \
      libboost-regex-dev \
      libboost-coroutine-dev \
      libtool \
      doxygen \
      ca-certificates \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD . /blockchain-wallet-core
WORKDIR /blockchain-wallet-core

# Compile
RUN \
    ( git submodule sync --recursive || \
      find `pwd`  -type f -name .git | \
	while read f; do \
	  rel="$(echo "${f#$PWD/}" | sed 's=[^/]*/=../=g')"; \
	  sed -i "s=: .*/.git/=: $rel/=" "$f"; \
	done && \
      git submodule sync --recursive ) && \
    git submodule update --init --recursive && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
	-DGRAPHENE_DISABLE_UNITY_BUILD=ON \
        . && \
    make witness_node cli_wallet get_dev_key && \
    install -s programs/witness_node/witness_node \
               programs/genesis_util/get_dev_key \
               programs/cli_wallet/cli_wallet \
            /usr/local/bin && \
    #
    # Obtain version
    mkdir -p /etc/blockchain-wallet && \
    git rev-parse --short HEAD > /etc/blockchain-wallet/version && \
    cd / && \
    rm -rf /blockchain-wallet-core

# The final image
FROM phusion/baseimage:focal-1.2.0
LABEL maintainer="The blockchain-wallet decentralized organisation"
ENV LANG=en_US.UTF-8

# Install required libraries
RUN \
    apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      libcurl4 \
      ca-certificates \
    && \
    mkdir -p /etc/blockchain-wallet && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build /usr/local/bin/* /usr/local/bin/
COPY --from=build /etc/blockchain-wallet/version /etc/blockchain-wallet/

WORKDIR /
RUN groupadd -g 10001 blockchain-wallet
RUN useradd -u 10000 -g blockchain-wallet -s /bin/bash -m -d /var/lib/blockchain-wallet --no-log-init blockchain-wallet
ENV HOME /var/lib/blockchain-wallet
RUN chown blockchain-wallet:blockchain-wallet -R /var/lib/blockchain-wallet

# default exec/config files
ADD docker/default_config.ini /etc/blockchain-wallet/config.ini
ADD docker/default_logging.ini /etc/blockchain-wallet/logging.ini
ADD docker/blockchain-walletentry.sh /usr/local/bin/blockchain-walletentry.sh
RUN chmod a+x /usr/local/bin/blockchain-walletentry.sh

# Volume
VOLUME ["/var/lib/blockchain-wallet", "/etc/blockchain-wallet"]

# rpc service:
EXPOSE 8090
# p2p service:
EXPOSE 1776

# Make Docker send SIGINT instead of SIGTERM to the daemon
STOPSIGNAL SIGINT

# Temporarily commented out due to permission issues caused by older versions, to be restored in a future version
#USER blockchain-wallet:blockchain-wallet

# default execute entry
ENTRYPOINT ["/usr/local/bin/blockchain-walletentry.sh"]
# ABOUTME: Build environment for sendo: ESP-IDF for the firmware, Lua and Fennel for the logic.
# ABOUTME: Everything `make check` and `make firmware` need, at pinned versions. Use via scripts/in-docker.

FROM espressif/idf:v6.1

ARG LUA_VERSION=5.5.1
ARG LUA_SHA256=1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce
ARG FENNEL_VERSION=1.6.1
ARG FENNEL_SHA256=8d0c1e838c5604b42151ea8696a41251bebacf299273c3c5b3c99c0c5ad7d6d7
ARG FENNEL_LS_VERSION=0.2.4
ARG FENNEL_LS_COMMIT=0b415097df22fbf3bba8ffa13d511548efa60cae

# Lua twice: `lua` runs Fennel and the tests; `lua32` uses 32-bit integers and
# floats like the firmware's espressif/lua component (make test32, bundle-check).
RUN curl -sSfL -o /tmp/lua.tar.gz "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" \
 && echo "${LUA_SHA256}  /tmp/lua.tar.gz" | sha256sum -c - \
 && mkdir /tmp/lua /tmp/lua32 \
 && tar -xzf /tmp/lua.tar.gz -C /tmp/lua --strip-components=1 \
 && tar -xzf /tmp/lua.tar.gz -C /tmp/lua32 --strip-components=1 \
 && make -C /tmp/lua posix \
 && make -C /tmp/lua32 posix MYCFLAGS=-DLUA_32BITS \
 && install -m 755 /tmp/lua/src/lua /usr/local/bin/lua \
 && install -m 755 /tmp/lua32/src/lua /usr/local/bin/lua32 \
 && rm -rf /tmp/lua.tar.gz /tmp/lua /tmp/lua32

RUN curl -sSfL -o /usr/local/bin/fennel "https://fennel-lang.org/downloads/fennel-${FENNEL_VERSION}" \
 && echo "${FENNEL_SHA256}  /usr/local/bin/fennel" | sha256sum -c - \
 && chmod 755 /usr/local/bin/fennel

# Only the executable: `make install` also builds a man page, which needs pandoc.
RUN git clone --quiet --depth 1 --branch "${FENNEL_LS_VERSION}" https://git.sr.ht/~xerool/fennel-ls /tmp/fennel-ls \
 && test "$(git -C /tmp/fennel-ls rev-parse HEAD)" = "${FENNEL_LS_COMMIT}" \
 && make -C /tmp/fennel-ls fennel-ls \
 && install -m 755 /tmp/fennel-ls/fennel-ls /usr/local/bin/fennel-ls \
 && rm -rf /tmp/fennel-ls

# Makefile: use the built-in 32-bit Lua instead of downloading one.
ENV LUA32=/usr/local/bin/lua32

COPY scripts/docker-entrypoint /usr/local/bin/sendo-entrypoint
ENTRYPOINT ["/usr/local/bin/sendo-entrypoint"]

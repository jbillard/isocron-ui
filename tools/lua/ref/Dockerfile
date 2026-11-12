# The reference interpreter of Lua 5.4 (that of the authors, C), for the
# tests of the interpreter of the library (tests/lua.sh): each script of
# tests/lua run by both, their outputs compared. Nothing of the library runs
# inside.
FROM alpine:3.22
RUN apk add --no-cache lua5.4
WORKDIR /work
ENTRYPOINT ["lua5.4"]

#!/usr/bin/env bash
# Runs COMMAND... on the host against a Weston without a screen (in Docker,
# image `isocron-ui-display`, made by `docker build -t isocron-ui-display
# tools/display`), then writes a screenshot of its output to SHOT (a PNG).
#   tools/display/run.sh SHOT COMMAND...
# The command sees WAYLAND_DISPLAY and XDG_RUNTIME_DIR; its exit code is
# this script's. WESTON_WIDTH and WESTON_HEIGHT: the size of the screen
# (640 by 480 by default). The compositor runs as the user of the host (its socket
# then belongs to it) and is stopped at the end.
set -euo pipefail
shot="$1"
shift
dir="$(mktemp -d)"
chmod 700 "$dir"
name="isocron-ui-weston-$$"
docker run -d --rm --name "$name" --user "$(id -u):$(id -g)" \
    -v "$dir:/run/display" -e XDG_RUNTIME_DIR=/run/display \
    isocron-ui-display weston --backend=headless-backend.so --use-pixman \
    --socket=wayland-test --width="${WESTON_WIDTH:-640}" --height="${WESTON_HEIGHT:-480}" --idle-time=0 --debug > /dev/null
cleanup() {
    docker stop -t 2 "$name" > /dev/null 2>&1 || true
    rm -r -- "$dir"
}
trap cleanup EXIT
for _ in $(seq 100); do
    [ -S "$dir/wayland-test" ] && break
    sleep 0.1
done
[ -S "$dir/wayland-test" ] || { echo "no socket of Weston"; docker logs "$name" 2>&1 | tail -20; exit 1; }
set +e
WAYLAND_DISPLAY=wayland-test XDG_RUNTIME_DIR="$dir" "$@" &
pid=$!
# the screenshot while the program shows its window (it ends after its
# frames: asked to show many, it is still there)
sleep "${SHOT_AFTER:-1}"
docker exec -w /run/display -e WAYLAND_DISPLAY=wayland-test "$name" weston-screenshooter > /dev/null 2>&1
wait "$pid"
code=$?
set -e
png="$(ls "$dir"/*.png 2>/dev/null | head -1 || true)"
if [ -n "$png" ]; then
    cp "$png" "$shot"
else
    echo "no screenshot"
fi
exit "$code"

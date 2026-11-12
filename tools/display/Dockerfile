# Display servers without a screen for the tests of the library: Weston
# (Wayland, its headless backend drawn by pixman, `weston-screenshooter`;
# or its X11 backend in a window of Xvfb, whose input `xdotool` plays) and
# Xvfb (X11, `xwd` for its images). Nothing of the library runs inside:
# the programs under test run on the host and speak to the sockets of these
# servers through a folder shared with the container.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends weston xvfb x11-apps x11-xserver-utils x11-xkb-utils xdotool wl-clipboard xclip xsel \
    && rm -r /var/lib/apt/lists

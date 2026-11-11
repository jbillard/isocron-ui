# Display servers without a screen for the tests of the library: Weston
# (Wayland, its headless backend drawn by pixman, `weston-screenshooter`)
# and Xvfb (X11, `xwd` for its images). Nothing of the library runs inside:
# the programs under test run on the host and speak to the sockets of these
# servers through a folder shared with the container.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends weston xvfb x11-apps \
    && rm -r /var/lib/apt/lists

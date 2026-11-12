# A compositor of Wayland that gives a fractional scale to its windows
# (wp_fractional_scale_v1 and wp_viewporter: sway on wlroots 0.18), without
# a screen (its headless backend, drawn by pixman), for the tests of the
# library at a scale of 1.5; grim for its images, swaymsg for its pointer.
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends sway grim wlrctl \
    && rm -r /var/lib/apt/lists

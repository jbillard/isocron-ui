#!/usr/bin/env python3
"""Plays the input of a hand to a program of the library under Wayland.

Weston runs in Docker (image `isocron-ui-display`) with its X11 backend in
a window of Xvfb, and kiosk-shell: the window of the program fills its
output from (0, 0), so a point of the screen of Xvfb is the same point of
the window. `xdotool` moves the pointer of Xvfb, presses its buttons and
its keys; Weston gives them to the program as the input of its seat.

The program (run on the host) prints a line starting with `ready` when it
is first shown, then the centres of its buttons as `[(id, x, y), ...]`.
The actions, in their order:
  click:ID     the pointer moved to the centre of the button ID, the left
               button pressed and released (the program prints the centres)
  clickat:X,Y  the same at a point of the window
  dblclickat:X,Y  two clicks there, 80 ms apart
  rclickat:X,Y the right button there
  type:TEXT    the keys of TEXT typed (xdotool type)
  wheel:X,Y,N  the pointer moved to a point of the window, the wheel turned
               by N notches (down when positive, up when negative)
  endserver    Weston stopped: the program sees its connection closed
  key:NAME     a key of xdotool pressed and released (Up, Down, r, Escape)
  shot:FILE    the screen of Weston written to FILE (PNG)
  move:X,Y     the pointer moved to a point of the window
  wait:SECONDS
  copy:TEXT    TEXT made the selection of another program (wl-copy)
  paste:FILE   the selection, of whatever program, written to FILE (wl-paste)
Then the program's output to its end.

PLAY_X11=1: no Weston, the program a client of Xvfb itself (its socket in
a folder shared with the container, DISPLAY its path); without a manager
of windows, its window at (0, 0) of the screen. PLAY_DPI with it: the
density the resources of the server give (`Xft.dpi`, set by xrdb).

usage: play.py WIDTH HEIGHT ACTIONS... -- COMMAND...
"""
import os
import re
import struct
import subprocess
import sys
import tempfile
import time
import zlib


def xwd_to_png(xwd, png):
    """The image of `xwd -root` (32 bits a pixel) written as a PNG."""
    head = struct.unpack(">25I", xwd[:100])
    size, width, height, order, bpp, line, ncolors = head[0], head[4], head[5], head[7], head[11], head[12], head[19]
    if bpp != 32:
        raise ValueError("xwd: %d bits a pixel" % bpp)
    data = xwd[size + 12 * ncolors:]
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            p = data[y * line + 4 * x: y * line + 4 * x + 4]
            b, g, r = (p[0], p[1], p[2]) if order == 0 else (p[3], p[2], p[1])
            row += bytes([r, g, b])
        rows.append(bytes(row))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    with open(png, "wb") as out:
        out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                  + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))


def main():
    args = sys.argv[1:]
    cut = args.index("--")
    width, height = int(args[0]), int(args[1])
    actions, command = args[2:cut], args[cut + 1:]
    run_dir = tempfile.mkdtemp()
    os.chmod(run_dir, 0o700)
    name = "isocron-ui-play-%d" % os.getpid()
    # PLAY_SCALE: the scale of the screen of Weston (its output twice as
    # many pixels a unit with 2), the screen of Xvfb as large in pixels
    scale = int(os.environ.get("PLAY_SCALE", "1"))
    x11 = os.environ.get("PLAY_X11") == "1"
    dpi = os.environ.get("PLAY_DPI")
    server = (
        "Xvfb :1 -screen 0 %dx%dx24 -nolisten tcp & sleep 1; "
        "DISPLAY=:1 exec weston --backend=x11-backend.so --use-pixman --shell=kiosk-shell.so "
        "--socket=wayland-test --width=%d --height=%d --scale=%d --idle-time=0 --debug 2>/run/display/weston.log"
    ) % (width * scale, height * scale, width, height, scale)
    if x11:
        # (-noreset: a server reset when its last client leaves, the
        # resources set by xrdb then lost before the program comes)
        server = "exec Xvfb :1 -screen 0 %dx%dx24 -nolisten tcp -noreset 2>/tmp/.X11-unix/xvfb.log" % (width, height)
    mount = "%s:%s" % (run_dir, "/tmp/.X11-unix" if x11 else "/run/display")
    subprocess.run(
        ["docker", "run", "-d", "--rm", "--name", name, "--user", "%d:%d" % (os.getuid(), os.getgid()),
         "-v", mount, "-e", "XDG_RUNTIME_DIR=/run/display",
         "isocron-ui-display", "sh", "-c", server],
        check=True, stdout=subprocess.DEVNULL)

    def xdo(*a):
        subprocess.run(["docker", "exec", name, "env", "DISPLAY=:1", "xdotool", *a], check=True)

    code = 1
    try:
        for _ in range(100):
            if os.path.exists(os.path.join(run_dir, "X1" if x11 else "wayland-test")):
                break
            time.sleep(0.1)
        time.sleep(0.5)
        env = dict(os.environ, WAYLAND_DISPLAY="wayland-test", XDG_RUNTIME_DIR=run_dir)
        if x11:
            env = dict(os.environ, DISPLAY=os.path.join(run_dir, "X1"))
            env.pop("WAYLAND_DISPLAY", None)
            if dpi:
                subprocess.run(["docker", "exec", "-i", name, "env", "DISPLAY=:1", "xrdb", "-merge"],
                               input=("Xft.dpi: %s\n" % dpi).encode(), check=True)
        prog = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, text=True)
        centres = {}
        lines = prog.stdout if any(a.startswith("click:") for a in actions) else []
        if not lines:
            time.sleep(2)
        for line in lines:
            print(line, end="")
            if line.startswith("ready"):
                buttons = prog.stdout.readline()
                print(buttons, end="")
                for i, x, y in re.findall(r"\((-?\d+), (-?\d+), (-?\d+)\)", buttons):
                    centres[int(i)] = (int(x), int(y))
                break
        for a in actions:
            kind, _, arg = a.partition(":")
            if kind == "click":
                x, y = centres[int(arg)]
                xdo("mousemove", str(x), str(y))
                time.sleep(0.15)
                xdo("click", "1")
            elif kind == "clickat":
                x, y = arg.split(",")
                xdo("mousemove", x, y)
                time.sleep(0.15)
                xdo("click", "1")
            elif kind == "wheel":
                x, y, n = arg.split(",")
                xdo("mousemove", x, y)
                time.sleep(0.15)
                xdo("click", "--repeat", str(abs(int(n))), "--delay", "60", "5" if int(n) > 0 else "4")
            elif kind == "move":
                x, y = arg.split(",")
                xdo("mousemove", x, y)
            elif kind == "rclickat":
                x, y = arg.split(",")
                xdo("mousemove", x, y)
                time.sleep(0.15)
                xdo("click", "3")
            elif kind == "dblclickat":
                x, y = arg.split(",")
                xdo("mousemove", x, y)
                time.sleep(0.15)
                xdo("click", "--repeat", "2", "--delay", "80", "1")
            elif kind == "type":
                xdo("type", "--delay", "60", arg)
            elif kind == "key":
                xdo("key", arg)
            elif kind == "shot" and x11:
                time.sleep(0.3)
                got = subprocess.run(["docker", "exec", name, "env", "DISPLAY=:1", "xwd", "-root", "-silent"], stdout=subprocess.PIPE, check=True)
                xwd_to_png(got.stdout, arg)
            elif kind == "shot":
                time.sleep(0.3)
                for f in os.listdir(run_dir):
                    if f.endswith(".png"):
                        os.remove(os.path.join(run_dir, f))
                subprocess.run(["docker", "exec", "-w", "/run/display", "-e", "WAYLAND_DISPLAY=wayland-test", name,
                                "weston-screenshooter"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                shots = [f for f in os.listdir(run_dir) if f.endswith(".png")]
                if shots:
                    os.replace(os.path.join(run_dir, shots[0]), arg)
                else:
                    print("no screenshot")
            elif kind == "endserver":
                server_name = "Xvfb" if x11 else "weston"
                subprocess.run(["docker", "exec", name, "sh", "-c", "kill $(pidof %s)" % server_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif kind == "wait":
                time.sleep(float(arg))
            elif kind == "copy" and x11:
                # (xclip stays to give the text: started apart)
                subprocess.run(["docker", "exec", "-d", "-e", "DISPLAY=:1", name, "sh", "-c",
                                "printf %s \"$0\" | xclip -selection clipboard -target UTF8_STRING -i -quiet", arg], check=True)
                time.sleep(0.6)
            elif kind == "copy":
                # (it stays to give the text: started apart)
                subprocess.run(["docker", "exec", "-d", "-e", "WAYLAND_DISPLAY=wayland-test", "-e", "XDG_RUNTIME_DIR=/run/display", name,
                                "wl-copy", "--foreground", "--type", "text/plain;charset=utf-8", arg], check=True)
                time.sleep(0.6)
            elif kind == "paste":
                reader = (["env", "DISPLAY=:1", "timeout", "5", "xclip", "-selection", "clipboard", "-target", "UTF8_STRING", "-o"] if x11
                          else ["env", "WAYLAND_DISPLAY=wayland-test", "XDG_RUNTIME_DIR=/run/display", "timeout", "5", "wl-paste", "--no-newline"])
                got = subprocess.run(["docker", "exec", name, *reader], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                with open(arg, "wb") as out:
                    out.write(got.stdout)
                if got.returncode != 0:
                    print("paste failed:", got.stderr.decode(errors="replace").strip())
            time.sleep(0.15)
        out, _ = prog.communicate(timeout=30)
        print(out, end="")
        code = prog.returncode
    finally:
        subprocess.run(["docker", "stop", "-t", "2", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for f in os.listdir(run_dir):
            os.remove(os.path.join(run_dir, f))
        os.rmdir(run_dir)
    sys.exit(code)


main()

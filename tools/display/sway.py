#!/usr/bin/env python3
"""Plays a hand to a program of the library under sway (in Docker, image
`isocron-ui-sway`): a compositor of Wayland that gives its windows a
fractional scale (wp_fractional_scale_v1, wp_viewporter). Its output has
WIDTH by HEIGHT units at SCALE (`SWAY_SCALE`, 1.5 by default): WIDTH x SCALE
by HEIGHT x SCALE pixels; the window of the program fills it.

The actions, in their order:
  clickat:X,Y  the pointer set at (X, Y) in units, the left button pressed
               and released (a virtual pointer, VirtualPointer)
  shot:FILE    the output written to FILE (PNG, by grim: its pixels)
  wait:SECONDS
  endserver    sway stopped: the program sees its connection closed
Then the program's output to its end.

usage: sway.py WIDTH HEIGHT ACTIONS... -- COMMAND...
"""
import glob
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time


class VirtualPointer:
    """A pointer of the seat of sway for the whole run: a client of Wayland
    spoken here on its socket (no library), holding a virtual pointer
    (`zwlr_virtual_pointer_v1`): the seat has a pointer while it lives."""

    def __init__(self, path, width, height):
        self.width, self.height = width, height
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.send(1, 1, struct.pack("<I", 2))   # wl_display.get_registry: 2
        self.send(1, 0, struct.pack("<I", 3))   # wl_display.sync: 3
        globals_ = {}
        data = b""
        done = False
        while not done:
            data += self.sock.recv(65536)
            while len(data) >= 8:
                obj, word = struct.unpack("<II", data[:8])
                size = word >> 16
                if len(data) < size:
                    break
                op, args = word & 0xFFFF, data[8:size]
                data = data[size:]
                if obj == 2 and op == 0:
                    name, n = struct.unpack("<II", args[:8])
                    globals_[args[8:8 + n - 1].decode()] = name
                if obj == 3:
                    done = True
        self.bind(globals_["wl_seat"], "wl_seat", 1, 4)
        self.bind(globals_["zwlr_virtual_pointer_manager_v1"], "zwlr_virtual_pointer_manager_v1", 1, 5)
        self.send(5, 0, struct.pack("<II", 4, 6))   # create_virtual_pointer(seat, 6)

    def send(self, obj, op, args):
        self.sock.sendall(struct.pack("<II", obj, ((8 + len(args)) << 16) | op) + args)

    def bind(self, name, iface, version, new):
        b = iface.encode() + b"\0"
        b += b"\0" * ((4 - len(b) % 4) % 4)
        self.send(2, 0, struct.pack("<II", name, len(iface) + 1) + b + struct.pack("<II", version, new))

    def click(self, x, y):
        t = int(time.monotonic() * 1000) & 0xFFFFFFFF
        self.send(6, 1, struct.pack("<IIIII", t, int(x), int(y), self.width, self.height))   # motion_absolute
        self.send(6, 4, struct.pack("<I", t))   # frame
        time.sleep(0.15)
        self.send(6, 2, struct.pack("<III", t + 150, 272, 1))   # BTN_LEFT pressed
        self.send(6, 4, struct.pack("<I", t + 150))
        time.sleep(0.05)
        self.send(6, 2, struct.pack("<III", t + 200, 272, 0))
        self.send(6, 4, struct.pack("<I", t + 200))


def main():
    args = sys.argv[1:]
    cut = args.index("--")
    width, height = int(args[0]), int(args[1])
    actions, command = args[2:cut], args[cut + 1:]
    scale = float(os.environ.get("SWAY_SCALE", "1.5"))
    run_dir = tempfile.mkdtemp()
    os.chmod(run_dir, 0o700)
    name = "isocron-ui-sway-%d" % os.getpid()
    with open(os.path.join(run_dir, "config"), "w") as c:
        c.write("output HEADLESS-1 resolution %dx%d scale %s\n" % (round(width * scale), round(height * scale), scale))
        c.write("default_border none\ndefault_floating_border none\nfocus_follows_mouse no\n")
        # (the cursor hidden after 200 ms still: not in the images)
        c.write("seat * hide_cursor 200\n")
    subprocess.run(
        ["docker", "run", "-d", "--rm", "--name", name, "--user", "%d:%d" % (os.getuid(), os.getgid()),
         "-v", "%s:/run/display" % run_dir, "-e", "XDG_RUNTIME_DIR=/run/display",
         "-e", "WLR_BACKENDS=headless", "-e", "WLR_LIBINPUT_NO_DEVICES=1", "-e", "WLR_RENDERER=pixman",
         # (SWAY_PROTOCOL set: every message of the protocol in its log)
         *(["-e", "WAYLAND_DEBUG=server"] if os.environ.get("SWAY_PROTOCOL") else []),
         "isocron-ui-sway", "sh", "-c", "exec sway -d -c /run/display/config 2>/run/display/sway.log"],
        check=True, stdout=subprocess.DEVNULL)

    def ipc(*a, check=True):
        socks = glob.glob(os.path.join(run_dir, "sway-ipc.*.sock"))
        inside = "/run/display/" + os.path.basename(socks[0])
        subprocess.run(["docker", "exec", "-e", "SWAYSOCK=" + inside, name, "swaymsg", *a], check=check, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    code = 1
    try:
        for _ in range(100):
            if glob.glob(os.path.join(run_dir, "wayland-*")) and glob.glob(os.path.join(run_dir, "sway-ipc.*.sock")):
                break
            time.sleep(0.1)
        time.sleep(0.5)
        wayland = sorted(os.path.basename(p) for p in glob.glob(os.path.join(run_dir, "wayland-*")) if not p.endswith(".lock"))[0]
        env = dict(os.environ, WAYLAND_DISPLAY=wayland, XDG_RUNTIME_DIR=run_dir)
        # a pointer for the seat, which has none, before the program
        pointer = VirtualPointer(os.path.join(run_dir, wayland), width, height)
        prog = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, text=True)
        time.sleep(2)
        for a in actions:
            kind, _, arg = a.partition(":")
            if kind == "clickat":
                x, y = arg.split(",")
                pointer.click(x, y)
            elif kind == "shot":
                time.sleep(0.5)
                subprocess.run(["docker", "exec", "-e", "WAYLAND_DISPLAY=" + wayland, "-e", "XDG_RUNTIME_DIR=/run/display", name,
                                "grim", "/run/display/shot.png"], check=True)
                os.replace(os.path.join(run_dir, "shot.png"), arg)
            elif kind == "wait":
                time.sleep(float(arg))
            elif kind == "endserver":
                # (sway ends before it answers)
                ipc("exit", check=False)
            time.sleep(0.15)
        out, _ = prog.communicate(timeout=30)
        print(out, end="")
        code = prog.returncode
    finally:
        # SWAY_LOG set: the end of the log of sway
        if os.environ.get("SWAY_LOG"):
            log = os.path.join(run_dir, "sway.log")
            if os.path.exists(log):
                print("".join(open(log, errors="replace").readlines()[-int(os.environ["SWAY_LOG"]):]), file=sys.stderr)
        subprocess.run(["docker", "stop", "-t", "2", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for f in os.listdir(run_dir):
            p = os.path.join(run_dir, f)
            if os.path.isfile(p) or os.path.islink(p) or os.path.exists(p):
                try:
                    os.remove(p)
                except OSError:
                    pass
        try:
            os.rmdir(run_dir)
        except OSError:
            pass
    sys.exit(code)


main()

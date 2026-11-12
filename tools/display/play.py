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
Then the program's output to its end.

usage: play.py WIDTH HEIGHT ACTIONS... -- COMMAND...
"""
import os
import re
import subprocess
import sys
import tempfile
import time


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
    server = (
        "Xvfb :1 -screen 0 %dx%dx24 -nolisten tcp & sleep 1; "
        "DISPLAY=:1 exec weston --backend=x11-backend.so --use-pixman --shell=kiosk-shell.so "
        "--socket=wayland-test --width=%d --height=%d --scale=%d --idle-time=0 --debug 2>/run/display/weston.log"
    ) % (width * scale, height * scale, width, height, scale)
    subprocess.run(
        ["docker", "run", "-d", "--rm", "--name", name, "--user", "%d:%d" % (os.getuid(), os.getgid()),
         "-v", "%s:/run/display" % run_dir, "-e", "XDG_RUNTIME_DIR=/run/display",
         "isocron-ui-display", "sh", "-c", server],
        check=True, stdout=subprocess.DEVNULL)

    def xdo(*a):
        subprocess.run(["docker", "exec", name, "env", "DISPLAY=:1", "xdotool", *a], check=True)

    code = 1
    try:
        for _ in range(100):
            if os.path.exists(os.path.join(run_dir, "wayland-test")):
                break
            time.sleep(0.1)
        time.sleep(0.5)
        env = dict(os.environ, WAYLAND_DISPLAY="wayland-test", XDG_RUNTIME_DIR=run_dir)
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
                subprocess.run(["docker", "exec", name, "sh", "-c", "kill $(pidof weston)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif kind == "wait":
                time.sleep(float(arg))
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

#!/usr/bin/env python3
"""
ipu6-webcam-manager.py
Automatically manages the Intel IPU6 internal webcam via v4l2loopback.
- When an external USB webcam (like Logitech Brio 505) is connected (Docked):
    -> Tears down the loopback device (/dev/video50) and stops GStreamer so the internal webcam disappears completely.
- When no external USB webcam is connected (Undocked):
    -> Creates /dev/video50 and starts GStreamer to feed processed video from IPU6 via libcamera.
"""

import os
import signal
import subprocess
import sys
import time
import pyudev

LOOPBACK_DEV_NR = 50
LOOPBACK_DEV_PATH = f"/dev/video{LOOPBACK_DEV_NR}"
LOOPBACK_NAME = "Internal Webcam (IPU6)"
GST_CMD = [
    "/usr/bin/gst-launch-1.0",
    "-q",
    "libcamerasrc",
    "!",
    "queue",
    "!",
    "videoconvert",
    "!",
    "videoscale",
    "!",
    "video/x-raw,width=1280,height=720,format=YUY2",
    "!",
    "queue",
    "!",
    "v4l2sink",
    f"device={LOOPBACK_DEV_PATH}",
    "sync=false",
]

gst_process = None
running = True


def handle_sigterm(signum, frame):
    global running
    print("[manager] Received termination signal, cleaning up...")
    running = False
    stop_internal_webcam()
    sys.exit(0)


signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)


def has_external_webcam(context):
    """Returns True if any external USB video capture device is present."""
    for device in context.list_devices(subsystem="video4linux"):
        if device.device_node == LOOPBACK_DEV_PATH:
            continue
        parent = device.find_parent("usb")
        if parent is not None:
            # Found external USB video device
            name = device.attributes.get("name")
            name_str = name.decode("utf-8", errors="ignore") if name else "USB Camera"
            return True, f"{device.device_node} ({name_str})"
    return False, None


def ensure_loopback_device():
    """Creates the /dev/video50 loopback device if it doesn't already exist."""
    if not os.path.exists(LOOPBACK_DEV_PATH):
        print(f"[manager] Creating loopback device {LOOPBACK_DEV_PATH} ({LOOPBACK_NAME})...")
        subprocess.run(
            ["v4l2loopback-ctl", "add", "-n", LOOPBACK_NAME, "-x", "1", str(LOOPBACK_DEV_NR)],
            capture_output=True,
            text=True,
        )
        time.sleep(0.5)


def delete_loopback_device():
    """Deletes the /dev/video50 loopback device if it exists."""
    if os.path.exists(LOOPBACK_DEV_PATH):
        print(f"[manager] Deleting loopback device {LOOPBACK_DEV_PATH} so it disappears...")
        subprocess.run(
            ["v4l2loopback-ctl", "delete", str(LOOPBACK_DEV_NR)],
            capture_output=True,
            text=True,
        )


def start_internal_webcam():
    """Starts the loopback device and GStreamer streamer."""
    global gst_process
    if gst_process is not None and gst_process.poll() is None:
        return  # already running

    ensure_loopback_device()
    print("[manager] Starting IPU6 -> GStreamer streamer...")
    try:
        gst_process = subprocess.Popen(
            GST_CMD,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
    except Exception as e:
        print(f"[manager] Error starting GStreamer: {e}")


def stop_internal_webcam():
    """Stops GStreamer and removes the loopback device."""
    global gst_process
    if gst_process is not None:
        print("[manager] Stopping IPU6 GStreamer streamer...")
        gst_process.terminate()
        try:
            gst_process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            gst_process.kill()
        gst_process = None

    time.sleep(0.5)
    delete_loopback_device()


def main():
    global running
    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem="video4linux")

    # Initial state evaluation
    ext_present, ext_info = has_external_webcam(context)
    if ext_present:
        print(f"[manager] External webcam detected on startup: {ext_info}. Internal webcam disabled.")
        stop_internal_webcam()
    else:
        print("[manager] No external webcam detected (undocked). Enabling internal webcam.")
        start_internal_webcam()

    # Event loop
    while running:
        # Wait for device events with a timeout to also check gst_process health if undocked
        event = monitor.poll(timeout=2)

        # Check external webcam presence
        ext_present, ext_info = has_external_webcam(context)

        if ext_present:
            if gst_process is not None or os.path.exists(LOOPBACK_DEV_PATH):
                print(f"[manager] External webcam connected: {ext_info}. Disabling internal webcam.")
                stop_internal_webcam()
        else:
            if gst_process is None or gst_process.poll() is not None or not os.path.exists(LOOPBACK_DEV_PATH):
                print("[manager] External webcam disconnected (undocked). Enabling internal webcam.")
                start_internal_webcam()


if __name__ == "__main__":
    main()

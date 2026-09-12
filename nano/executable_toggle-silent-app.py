#!/usr/bin/env python3
import subprocess
import sys
import shutil

def get_apps():
    try:
        out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True)
    except Exception as e:
        return []
    
    # Ensure SilentRecording sink exists
    subprocess.run(["pactl", "load-module", "module-null-sink", "sink_name=SilentRecording", "sink_properties=device.description=Silent_Recording"], capture_output=True)

    # Get SilentRecording sink id
    sinks_out = subprocess.check_output(["pactl", "list", "short", "sinks"], text=True)
    silent_sink_id = None
    for line in sinks_out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and "SilentRecording" in parts[1]:
            silent_sink_id = parts[0]
            break

    blocks = out.split("Sink Input #")
    apps = []
    for b in blocks[1:]:
        lines = b.splitlines()
        id_val = lines[0].strip()
        app_name = "Unknown"
        media_name = ""
        sink_id = ""
        for line in lines:
            if "application.name =" in line:
                app_name = line.split("=")[1].strip().strip('"')
            elif "media.name =" in line:
                media_name = line.split("=")[1].strip().strip('"')
            elif "Sink:" in line:
                sink_id = line.split(":")[1].strip()
        
        if app_name != "speech-dispatcher-dummy":
            is_silent = (sink_id == silent_sink_id)
            apps.append({
                "id": id_val,
                "name": app_name,
                "media": media_name,
                "is_silent": is_silent,
                "sink_id": sink_id
            })
    return apps

def main():
    apps = get_apps()

    # If an argument is provided (e.g. ./toggle-silent-app.sh firefox)
    if len(sys.argv) > 1:
        target = sys.argv[1].lower()
        if target in ["all-speakers", "restore", "reset"]:
            for app in apps:
                subprocess.run(["pactl", "move-sink-input", app["id"], "@DEFAULT_SINK@"])
            print("Restored all applications to Speakers.")
            return

        found = False
        for app in apps:
            if target in app["name"].lower():
                subprocess.run(["pactl", "move-sink-input", app["id"], "SilentRecording"])
                print(f"Routed {app['name']} (Stream #{app['id']}) to Silent_Recording.")
                found = True
        if not found:
            print(f"No active audio stream found for '{target}'. Make sure audio is playing in the app.")
        return

    # If run without arguments, open a GUI dialog via kdialog
    if not apps:
        if shutil.which("kdialog"):
            subprocess.run(["kdialog", "--title", "Silent Audio Switcher", "--msgbox", "No applications are currently playing audio.\nStart playing video/audio in your app first, then run this tool."])
        else:
            print("No applications are currently playing audio.")
        return

    # Build kdialog menu
    menu_items = []
    for app in apps:
        status = "[SILENT on speakers]" if app["is_silent"] else "[PLAYING on speakers]"
        action = "Switch to SPEAKERS" if app["is_silent"] else "Switch to SILENT (Record only)"
        label = f"{app['name']} {status} -> {action}"
        menu_items.extend([app["id"], label])
    
    menu_items.extend(["reset_all", "Restore ALL apps to Speakers"])

    cmd = ["kdialog", "--title", "Audio Routing for Recording", "--menu", "Select an app to toggle its sound:", *menu_items]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return  # user cancelled

    selected_id = res.stdout.strip()
    if selected_id == "reset_all":
        for app in apps:
            subprocess.run(["pactl", "move-sink-input", app["id"], "@DEFAULT_SINK@"])
        subprocess.run(["kdialog", "--passivepopup", "All applications restored to Speakers", "3"])
    else:
        for app in apps:
            if app["id"] == selected_id:
                if app["is_silent"]:
                    subprocess.run(["pactl", "move-sink-input", app["id"], "@DEFAULT_SINK@"])
                    subprocess.run(["kdialog", "--passivepopup", f"{app['name']} is now playing on Speakers", "3"])
                else:
                    subprocess.run(["pactl", "move-sink-input", app["id"], "SilentRecording"])
                    subprocess.run(["kdialog", "--passivepopup", f"{app['name']} is now SILENT on speakers (recording only)", "3"])
                break

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
from collections import defaultdict
from typing import List
import asyncio
import os
import socket
import subprocess
import sys
from dataclasses import dataclass

DEBUG = False
StatusMap = defaultdict[int, bool]
occupied: StatusMap = defaultdict(bool)
focused: StatusMap = defaultdict(bool)

def log(target: str, message: str):
    if not DEBUG: return
    open(f'/tmp/eww-debug-{target}.log', 'a').write(f'{message}\n')

def workspaces_init():
    global DEBUG
    if "--verbose" in sys.argv:
        DEBUG = True

    occupied_workspaces = subprocess.check_output("hyprctl workspaces | grep ID | awk '{print $3}'", shell=True)
    for workspace_id in occupied_workspaces.split():
        occupied[int(workspace_id.strip().decode("utf-8"))] = True

    focused_workspaces = subprocess.check_output("""hyprctl monitors | grep -B 5 "focused: yes" | awk 'NR==1{print $3}'""", shell=True)
    for workspace_id in focused_workspaces.split():
        focused[int(workspace_id.strip().decode("utf-8"))] = True

workspaces = [
    (1, "", ""),
    (2, "", ""),
    (3, "", ""),
    (4, "", ""),
    (5, "󰇮", "󰇮"),
    (6, "", ""),
    (7, "", ""),
    (8, "", ""),
    (9, "", ""),
    (10, "", ""),
]

def workspaces_view():
    buttons: List[str] = []
    for id, occupied_icon, focused_icon in workspaces:
        empty_icon = ""
        focus_class = " focused" if focused[id] else ""
        occupied_class = " occupied" if occupied[id] else ""
        icon =  focused_icon if focused[id] else occupied_icon if occupied[id] else empty_icon
        buttons.append(f"""(button :onclick "hyprctl dispatch workspace {id}" :class "workspace{focus_class}{occupied_class}" "{icon}")""")
    message = f"""(box :class "works" :orientation "h" :spacing 5 :space-evenly "false" {" ".join(buttons)})"""
    print(message, flush=True)

class EventListener:
    async def async_start(self):
        reader, writer = await asyncio.open_unix_connection(f"/tmp/hypr/{os.getenv('HYPRLAND_INSTANCE_SIGNATURE')}/.socket2.sock")
        yield "connect"
        while True:
            data = await reader.readline()
            if not data:
                break
            yield data.decode('utf-8')

@dataclass
class ConnectEvent:
    pass

@dataclass
class FocusedMonitorEvent:
    name: str
    monitor: str
    workspace: int

@dataclass
class WorkspaceEvent:
    name: str
    workspace: int

@dataclass
class CreateWorkspaceEvent:
    name: str
    workspace: int

@dataclass
class DestroyWorkspaceEvent:
    name: str
    workspace: int

@dataclass
class UnknownEvent:
    name: str
    args: str


Event = ConnectEvent | FocusedMonitorEvent | WorkspaceEvent | DestroyWorkspaceEvent | CreateWorkspaceEvent | UnknownEvent

def parse_event(event: str) -> Event:
    event = event.strip()
    if event == "connect":
        return ConnectEvent()

    name, args = event.split(">>")
    if name == "focusedmon":
        monitor, workspace = args.strip().split(",")
        return FocusedMonitorEvent(name=name, monitor=monitor, workspace=int(workspace))
    elif name == "workspace":
        workspace = args.strip()
        return WorkspaceEvent(name=name, workspace=int(workspace))
    elif name == "createworkspace":
        workspace = args.strip()
        return CreateWorkspaceEvent(name=name, workspace=int(workspace))
    elif name == "destroyworkspace":
        workspace = args.strip()
        return DestroyWorkspaceEvent(name=name, workspace=int(workspace))

    return UnknownEvent(name=name, args=args)

def workspaces_focus(workspace_id: int):
    global focused
    focused = defaultdict(bool)
    focused[workspace_id] = True
    workspaces_occupy(workspace_id)

def workspaces_occupy(workspace_id: int):
    global occupied
    occupied[workspace_id] = True

def workspaces_unoccupy(workspace_id: int):
    global occupied
    occupied[workspace_id] = False

async def main():
    global focused
    global occupied
    global DEBUG
    if "--debug" in sys.argv:
        DEBUG = True

    workspaces_init()
    workspaces_view()
    event_listener = EventListener()
    async for event_string in event_listener.async_start():
        event = parse_event(event_string)
        match event:
            case FocusedMonitorEvent(_, _, workspace_id):
                workspaces_focus(workspace_id)
            case WorkspaceEvent(_, workspace_id):
                workspaces_focus(workspace_id)
            case CreateWorkspaceEvent(_, workspace_id):
                workspaces_occupy(workspace_id)
            case DestroyWorkspaceEvent(_, workspace_id):
                workspaces_unoccupy(workspace_id)
            case UnknownEvent(name, args):
                pass
        workspaces_view()

if __name__ == "__main__":
    asyncio.run(main())

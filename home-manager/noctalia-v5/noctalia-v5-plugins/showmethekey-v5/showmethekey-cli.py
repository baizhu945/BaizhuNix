#!/usr/bin/env python3

import json
import sys
from collections import OrderedDict
from pathlib import Path
import threading

CLEAR_DELAY = 2.0

clear_timer = None
ENABLE_FLAG = Path("/tmp/showkeys-enabled")

# 修饰键名称映射

MODIFIER_BASE = {
    "CTRL": "Ctrl",
    "SHIFT": "Shift",
    "ALT": "Alt",
    "META": "Super",
    "SUPER": "Super",
}

SIDE = {
    "LEFT": "Left",
    "RIGHT": "Right",
}

# 鼠标按键映射

MOUSE_BUTTONS = {
    "LEFT": "LeftClick",
    "RIGHT": "RightClick",
    "MIDDLE": "MiddleClick",
    "SIDE": "SideButton",
    "EXTRA": "ExtraButton",
    "FORWARD": "ForwardButton",
    "BACK": "BackButton",
    "WHEELUP": "WheelUp",
    "WHEELDOWN": "WheelDown",
}

# 特殊键映射

SPECIAL_KEYS = {
    "ESC": "Esc",
    "ENTER": "Enter",
    "TAB": "Tab",
    "SPACE": "Space",
    "BACKSPACE": "Backspace",
    "DELETE": "Delete",
    "INSERT": "Insert",
    "HOME": "Home",
    "END": "End",
    "PAGEUP": "PageUp",
    "PAGEDOWN": "PageDown",
    "LEFT": "Left",
    "RIGHT": "Right",
    "UP": "Up",
    "DOWN": "Down",
    "CAPSLOCK": "CapsLock",
    "NUMLOCK": "NumLock",
    "SCROLLLOCK": "ScrollLock",
    "PRINTSCREEN": "PrintScreen",
    "PAUSE": "Pause",
    "MENU": "Menu",
    "LEFTBRACE": "LeftBrace",
    "RIGHTBRACE": "RightBrace",
    "MINUS": "Minus",
    "EQUAL": "Equal",
    "DOT": "Dot",
    "COMMA": "Comma",
    "SLASH": "Slash",
    "BACKSLASH": "Backslash",
    "SEMICOLON": "Semicolon",
    "APOSTROPHE": "Apostrophe",
    "GRAVE": "Grave",
    "KPENTER": "KeypadEnter",
    "KPSLASH": "KeypadSlash",
    "KPASTERISK": "KeypadAsterisk",
    "KPMINUS": "KeypadMinus",
    "KPPLUS": "KeypadPlus",
    "KPDOT": "KeypadDot",
}

def output_enabled():
    return ENABLE_FLAG.exists()


def emit(text: str, cls: str):
    global clear_timer

    if not output_enabled():
        return

    print(
        json.dumps(
            {
                "text": f"⌨ {text}",
                "class": cls,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )

    # 重置自动清空计时器
    if clear_timer is not None:
        clear_timer.cancel()

    clear_timer = threading.Timer(
        CLEAR_DELAY,
        emit_clear,
    )
    clear_timer.daemon = True
    clear_timer.start()


def emit_clear():
    print(
        json.dumps(
            {
                "text": "",
                "class": "hidden",
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def is_modifier_key(key_name: str) -> bool:
    if not key_name.startswith("KEY_"):
        return False

    name = key_name[4:]

    if name in MODIFIER_BASE:
        return True

    for side in ("LEFT", "RIGHT"):
        for base in ("CTRL", "SHIFT", "ALT", "META", "SUPER"):
            if name == side + base:
                return True

    return False


def pretty_key(key_name: str):

    # 鼠标
    if key_name.startswith("BTN_"):
        btn = key_name[4:]

        if btn in MOUSE_BUTTONS:
            return MOUSE_BUTTONS[btn], "mouse"

        return "Mouse" + btn.title(), "mouse"

    # 键盘
    if key_name.startswith("KEY_"):
        name = key_name[4:]
    else:
        name = key_name

    for side in ("LEFT", "RIGHT"):
        for base, pretty_base in MODIFIER_BASE.items():
            if name == side + base:
                return SIDE[side] + pretty_base, "keyboard"

    if name in MODIFIER_BASE:
        return MODIFIER_BASE[name], "keyboard"

    if name.startswith("F") and name[1:].isdigit():
        return name, "keyboard"

    if name.isdigit():
        return name, "keyboard"

    if len(name) == 1 and name.isalpha():
        return name.upper(), "keyboard"

    if name in SPECIAL_KEYS:
        return SPECIAL_KEYS[name], "keyboard"

    if name.startswith("KP") and name[2:].isdigit():
        return "Keypad" + name[2:], "keyboard"

    parts = name.split("_")

    return (
        "".join(
            p[:1].upper() + p[1:].lower()
            for p in parts
            if p
        ),
        "keyboard",
    )


def is_pressed(event):
    return (
        event.get("state_name") == "PRESSED"
        or event.get("state_code") == 1
    )


def is_released(event):
    return (
        event.get("state_name") == "RELEASED"
        or event.get("state_code") == 0
    )


def main():

    held_modifiers = OrderedDict()

    for line in sys.stdin:

        line = line.strip()

        if not line:
            continue

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        key_name = event.get("key_name")

        if not key_name:
            continue

        if is_pressed(event):

            if is_modifier_key(key_name):

                if key_name not in held_modifiers:
                    held_modifiers[key_name] = False

            else:

                mods = [
                    pretty_key(k)[0]
                    for k in held_modifiers.keys()
                ]

                key, cls = pretty_key(key_name)

                if mods:

                    for k in held_modifiers:
                        held_modifiers[k] = True

                    emit(
                        " + ".join(mods + [key]),
                        cls,
                    )

                else:
                    emit(key, cls)

            continue

        if is_released(event):

            if (
                is_modifier_key(key_name)
                and key_name in held_modifiers
            ):

                if not held_modifiers[key_name]:

                    key, cls = pretty_key(key_name)

                    emit(key, cls)

                del held_modifiers[key_name]


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass

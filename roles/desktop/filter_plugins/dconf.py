#!/usr/bin/python

import re
from base64 import b64decode

class FilterModule(object):
    def filters(self):
        return {
            "parse_keyfile": parse_keyfile,
            "render_keyfile": render_keyfile,
            "merge_keyfiles": merge_keyfiles,
            "merge_slurped": merge_slurped,
        }


def parse_keyfile(keyfile_content: str) -> dict[str, dict[str, str]]:
    header_regex = re.compile(r"^\[(.+?)\]\s*$")
    entry_regex = re.compile(r"^\s*(.+?)\s*=\s*(.+?)\s*$")

    path = ""
    data = {}
    lines = keyfile_content.split("\n")
    for line in lines:
        header_match = header_regex.match(line)
        if header_match:
            path, = header_match.groups()
            continue

        entry_match = entry_regex.match(line)
        if entry_match is None:
            continue

        settings = data.get(path)
        if settings is None:
            data[path] = settings = {}

        key, value = entry_match.groups()
        settings[key] = value

    return data

def render_keyfile(data: dict[str, dict[str, str]]) -> str:
    def gen():
        for path, settings in data.items():
            yield f"[{path}]"
            for key, value in settings.items():
                yield f"{key}={value}"
            yield ""
    return "\n".join(gen())

def merge_keyfiles(base: dict[str, dict[str, str]], *, update: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    data = {}
    for path, settings in base.items():
        data[path] = settings.copy()
    for path, settings in update.items():
        if path in data:
            data[path].update(settings)
        else:
            data[path] = settings.copy()

    data_ = {}
    for key, value in sorted(data.items()):
        data_[key] = value
    return data_

def merge_slurped(b64content: str, *, update: str) -> str:
    base_content = b64decode(b64content).decode()
    base = parse_keyfile(base_content)
    parsed_update = parse_keyfile(update)
    data = merge_keyfiles(base, update=parsed_update)
    return render_keyfile(data)

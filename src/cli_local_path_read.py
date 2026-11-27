#!/usr/bin/env python3
"""Read cli.local_path for selected hosts using Ansible's inventory resolution."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from odev_messages import print_message


def main():
    inventory, hosts, config, *options = sys.argv[1:]
    if not shutil.which("ansible-inventory"):
        print_message("missing_tool", "ansible-inventory", error=True)
        return 1

    result = subprocess.run(
        ["ansible-inventory", "--list", "--limit", hosts,
         "--playbook-dir", str(Path(inventory).parent), *options],
        env=dict(os.environ, ANSIBLE_CONFIG=config), stdout=subprocess.PIPE, text=True,
    )
    if result.returncode:
        return result.returncode
    try:
        data = json.loads(result.stdout)
        selected = {host for group in data.values() if isinstance(group, dict)
                    for host in group.get("hosts", [])}
        hostvars = data.get("_meta", {}).get("hostvars", {})
    except (ValueError, AttributeError):
        print_message("invalid_inventory", inventory, error=True)
        return 1
    if not selected:
        print_message("invalid_inventory", "%s (no hosts match %s)" % (inventory, hosts), error=True)
        return 1

    paths = set()
    for host in selected:
        cli = hostvars.get(host, {}).get("cli", {})
        path = cli.get("local_path") if isinstance(cli, dict) else None
        if not isinstance(path, str) or not path.strip():
            print_message("missing_value", "cli.local_path in group_vars/all/main.yml for %s" % host, error=True)
            return 1
        paths.add(path)
    if len(paths) != 1:
        print_message("invalid_value", "cli.local_path", ", ".join(sorted(paths)),
                      "one shared checkout for the selected hosts", error=True)
        return 1
    print(paths.pop())
    return 0


if __name__ == "__main__":
    sys.exit(main())

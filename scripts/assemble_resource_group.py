#!/usr/bin/env python3
"""Validate one Resource Group's inputjson files and emit the legacy Terraform input contract."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMAS = ROOT / "schemas" / "configuration"
ALLOWED_FILES = {
    "resource-group.json",
    "virtual-network.json",
    "subnet.json",
    "storage-account.json",
    "network-security-group.json",
}


def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"{path}: invalid or unreadable JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: top-level JSON value must be an object")
    return value


def validate_schema(name: str, data: dict, source: Path) -> None:
    try:
        import jsonschema
    except ImportError as exc:
        raise ValueError("Install validation dependencies with: python -m pip install -r requirements-validation.txt") from exc
    schema_path = SCHEMAS / name
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    resolver = jsonschema.RefResolver(base_uri=schema_path.as_uri(), referrer=schema)
    validator = jsonschema.Draft202012Validator(schema, resolver=resolver, format_checker=jsonschema.FormatChecker())
    errors = sorted(validator.iter_errors(data), key=lambda e: list(map(str, e.path)))
    if errors:
        detail = "; ".join(f"{'/'.join(map(str, e.path)) or '<root>'}: {e.message}" for e in errors)
        raise ValueError(f"{source}: schema validation failed: {detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", required=True, type=Path, help="Path to one Resource Group's inputjson directory")
    parser.add_argument("--output", required=True, type=Path, help="Generated Terraform JSON variable file")
    args = parser.parse_args()

    input_dir = args.input_dir.resolve()
    if input_dir.name != "inputjson" or not input_dir.is_dir():
        parser.error("--input-dir must point to an existing resource-groups/<name>/inputjson directory")
    folder = input_dir.parent.name
    if not re.fullmatch(r"rg-[a-z0-9]+(?:-[a-z0-9]+)*", folder):
        raise ValueError(f"Invalid Resource Group folder name: {folder}")
    present = {p.name for p in input_dir.glob("*.json")}
    unknown = present - ALLOWED_FILES
    if unknown:
        raise ValueError(f"Unsupported JSON file(s) in {input_dir}: {', '.join(sorted(unknown))}")
    required = {"resource-group.json"}
    if missing := required - present:
        raise ValueError(f"Missing required file(s): {', '.join(sorted(missing))}")

    rg_path = input_dir / "resource-group.json"
    rg = load_json(rg_path)
    validate_schema("resource-group.schema.json", rg, rg_path)
    instance = rg["instance"]
    resource_group = {"instance": instance, "tags": rg.get("tags", {})}

    if "virtual-network.json" in present:
        path = input_dir / "virtual-network.json"
        vnet = load_json(path)
        validate_schema("virtual-network.schema.json", vnet, path)
        subnet_data = {"subnets": []}
        if "subnet.json" in present:
            subnet_path = input_dir / "subnet.json"
            subnet_data = load_json(subnet_path)
            validate_schema("subnet.schema.json", subnet_data, subnet_path)
        elif "subnets" in vnet:
            subnet_data = {"subnets": vnet.pop("subnets")}
        resource_group["virtual_network"] = {
            "instance": vnet["instance"],
            "address_space": vnet["address_space"],
            "subnets": subnet_data.get("subnets", []),
        }
    elif "subnet.json" in present:
        raise ValueError("subnet.json requires virtual-network.json in the same Resource Group folder")

    storage_accounts = []
    if "storage-account.json" in present:
        path = input_dir / "storage-account.json"
        data = load_json(path)
        validate_schema("storage-account.schema.json", data, path)
        storage_accounts = data["storage_accounts"]
        for account in storage_accounts:
            if account["resource_group_instance"] != instance:
                raise ValueError(
                    f"Storage account {account['instance']!r} references Resource Group instance "
                    f"{account['resource_group_instance']!r}; expected {instance!r} for this folder"
                )

    # Reject a service file that is present but not implemented by the current Terraform root.
    if "network-security-group.json" in present:
        raise ValueError("network-security-group.json is not yet supported by Terraform; do not add an un-managed resource declaration")

    output = {
        "subscription_id": rg["subscription_id"],
        "org": rg["org"],
        "app": rg["app"],
        "env": rg["env"],
        "resource_groups": [resource_group],
        "storage_accounts": storage_accounts,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"Validated {folder}: 1 resource group, "
          f"{1 if resource_group.get('virtual_network') else 0} virtual network, "
          f"{len(resource_group.get('virtual_network', {}).get('subnets', []))} subnet(s), "
          f"{len(storage_accounts)} storage account(s).")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)

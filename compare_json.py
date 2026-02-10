import json
import sys
import re

zig_data = None
py_data = None

def floats_equal(a, b, rel_tol=1e-6):
    """Check if two floats are approximately equal."""
    if a == b:
        return True
    if a == 0 or b == 0:
        return abs(a - b) < 1e-9
    return abs(a - b) / max(abs(a), abs(b)) < rel_tol

# Fields that should be skipped due to known differences (timezone, etc.)
SKIP_FIELDS = {'timestamp'}  # Top-level timestamp has timezone issues

def compare(a, b, path=""):
    """Recursively compare two values, print first difference and exit."""
    if type(a) != type(b):
        # Allow int/float equivalence for numeric values
        if isinstance(a, (int, float)) and isinstance(b, (int, float)):
            if not floats_equal(float(a), float(b)):
                print(f"Value mismatch at {path or 'root'}:")
                print(f"  zig:    {repr(a)[:200]}")
                print(f"  python: {repr(b)[:200]}")
                sys.exit(1)
            return  # Values are close enough
        print(f"Type mismatch at {path or 'root'}:")
        print(f"  zig:    {type(a).__name__} = {repr(a)[:100]}")
        print(f"  python: {type(b).__name__} = {repr(b)[:100]}")
        sys.exit(1)

    if isinstance(a, dict):
        all_keys = set(a.keys()) | set(b.keys())
        for key in sorted(all_keys):
            new_path = f"{path}.{key}" if path else key
            # Skip known differing fields at top level
            if not path and key in SKIP_FIELDS:
                continue
            if key not in a:
                print(f"Missing in zig: {new_path}")
                print(f"  python has: {repr(b[key])[:200]}")
                # Show more context for actions
                match = re.search(r'actions\[(\d+)\]', path)
                if match:
                    idx = int(match.group(1))
                    print(f"  python action type: {py_data['actions'][idx].get('type', 'N/A')}")
                    print(f"  zig action type: {zig_data['actions'][idx].get('type', 'N/A')}")
                    print(f"  zig payload: {zig_data['actions'][idx].get('payload', {})}")
                sys.exit(1)
            if key not in b:
                print(f"Missing in python: {new_path}")
                print(f"  zig has: {repr(a[key])[:200]}")
                print(f"  python keys at {path}: {list(b.keys())}")
                # Show more context for actions
                if 'actions[' in path:
                    print(f"  python action type: {b.get('type', 'N/A')}")
                    print(f"  zig action type: {a.get('type', 'N/A')}")
                sys.exit(1)
            compare(a[key], b[key], new_path)
    elif isinstance(a, list):
        if len(a) != len(b):
            print(f"List length mismatch at {path or 'root'}:")
            print(f"  zig:    {len(a)} items")
            print(f"  python: {len(b)} items")
            sys.exit(1)
        for i, (x, y) in enumerate(zip(a, b)):
            compare(x, y, f"{path}[{i}]")
    else:
        # For floats, use tolerance comparison
        if isinstance(a, float) and isinstance(b, float):
            if not floats_equal(a, b):
                print(f"Value mismatch at {path or 'root'}:")
                print(f"  zig:    {repr(a)[:200]}")
                print(f"  python: {repr(b)[:200]}")
                sys.exit(1)
        elif a != b:
            print(f"Value mismatch at {path or 'root'}:")
            print(f"  zig:    {repr(a)[:200]}")
            print(f"  python: {repr(b)[:200]}")
            sys.exit(1)

with open('output.json') as f:
    zig = json.load(f)
with open('aoc-mgz/output.txt') as f:
    py = json.load(f)

zig_data = zig
py_data = py
compare(zig, py)
print("Files are identical!")

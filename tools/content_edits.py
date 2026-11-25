"""Hand edits to the content (made in Deschly Studio), kept so they survive when a tool rewrites a content file.

    python -I -X utf8 tools/content_edits.py            re-apply every recorded edit (run after any generator)
    python -I -X utf8 tools/content_edits.py --list     show the recorded edits

An edit names its place by a stable key, not by a list position:
    {"file": "a1.json", "collection": "words", "keyField": "id", "key": 101, "path": "mean.tr", "value": "meslek", ...}
`collection` is a list at the top of the file; the item is the one whose `keyField` equals `key`; `path` is a dotted
path inside that item (numbers index lists: "ex.0.mean.tr"). Only existing text fields can be edited.
tools/publish_content.py applies the edits before publishing, so a regenerated file never goes out without them.
"""
import datetime
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
EDITS = os.path.join(REPO, 'tools', 'content_edits.json')


def load_edits():
    try:
        return json.load(open(EDITS, encoding='utf-8'))
    except (OSError, ValueError):
        return []


def save_edits(edits):
    with open(EDITS, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(edits, f, ensure_ascii=False, indent=1)
        f.write('\n')


def read_file(name):
    if os.path.basename(name) != name or not name.endswith('.json'):
        raise ValueError('bad file name')
    path = os.path.join(CONTENT, name)
    raw = open(path, encoding='utf-8').read()
    return path, raw, json.loads(raw)


def write_file(path, raw, data):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        if raw.startswith('{"'):
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        else:
            indent = 1 if raw.startswith('{\n "') else 2
            json.dump(data, f, ensure_ascii=False, indent=indent)
            f.write('\n')


def locate(data, collection, key_field, key, path):
    """(container, last key) of the field, or ValueError."""
    items = data.get(collection)
    if not isinstance(items, list):
        raise ValueError(f'no list "{collection}"')
    item = next((x for x in items if isinstance(x, dict) and x.get(key_field) == key), None)
    if item is None:
        raise ValueError(f'no item with {key_field} = {key!r} in {collection}')
    parts = path.split('.')
    node = item
    for part in parts[:-1]:
        node = node[int(part)] if isinstance(node, list) else node.get(part)
        if node is None:
            raise ValueError(f'no field {path}')
    last = int(parts[-1]) if isinstance(node, list) else parts[-1]
    try:
        current = node[last]
    except (IndexError, KeyError, TypeError):
        raise ValueError(f'no field {path}') from None
    if not isinstance(current, str):
        raise ValueError(f'{path} is not a text')
    return node, last


def edit(file, collection, key_field, key, path, value):
    """Changes one text field in a content file and records it. Returns the old value."""
    value = value.strip()
    if not value:
        raise ValueError('empty text')
    full, raw, data = read_file(file)
    node, last = locate(data, collection, key_field, key, path)
    old = node[last]
    if old == value:
        return old
    node[last] = value
    write_file(full, raw, data)
    edits = [e for e in load_edits() if not (e['file'] == file and e['collection'] == collection and
                                              e['keyField'] == key_field and e['key'] == key and e['path'] == path)]
    original = next((e['original'] for e in load_edits() if e['file'] == file and e['collection'] == collection and
                     e['keyField'] == key_field and e['key'] == key and e['path'] == path), old)
    if value != original:  # back to the original text: nothing to remember
        edits.append({'file': file, 'collection': collection, 'keyField': key_field, 'key': key, 'path': path,
                      'value': value, 'original': original, 'at': datetime.datetime.now().isoformat(timespec='seconds')})
    save_edits(edits)
    return old


def apply_all(quiet=False):
    """Re-applies every recorded edit. Returns (applied, already there, failed)."""
    by_file = {}
    for e in load_edits():
        by_file.setdefault(e['file'], []).append(e)
    applied = same = 0
    failed = []
    for file, edits in by_file.items():
        try:
            full, raw, data = read_file(file)
        except (OSError, ValueError) as err:
            failed += [(e, str(err)) for e in edits]
            continue
        changed = False
        for e in edits:
            try:
                node, last = locate(data, e['collection'], e['keyField'], e['key'], e['path'])
            except ValueError as err:
                failed.append((e, str(err)))
                continue
            if node[last] == e['value']:
                same += 1
            else:
                node[last] = e['value']
                applied += 1
                changed = True
        if changed:
            write_file(full, raw, data)
    if not quiet:
        print(f'edits: {applied} applied, {same} already in place, {len(failed)} failed')
        for e, why in failed:
            print(f'  FAILED {e["file"]} {e["collection"]}[{e["keyField"]}={e["key"]}].{e["path"]}: {why}')
    return applied, same, failed


if __name__ == '__main__':
    if '--list' in sys.argv:
        for e in load_edits():
            print(f'{e["at"]}  {e["file"]} {e["collection"]}[{e["key"]}].{e["path"]}: {e["original"]!r} → {e["value"]!r}')
    else:
        apply_all()

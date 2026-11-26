"""Hand edits to the content (made in Deschly Studio), kept so they survive when a tool rewrites a content file.

    python -I -X utf8 tools/content_edits.py            re-apply every recorded edit (run after any generator)
    python -I -X utf8 tools/content_edits.py --list     show the recorded edits

An edit names its place by a stable key, not by a list position:
    {"file": "a1.json", "collection": "words", "keyField": "id", "key": 101, "path": "mean.tr", "value": "meslek", ...}
`collection` is a list at the top of the file; the item is the one whose `keyField` equals `key`; `path` is a dotted
path inside that item (numbers index lists: "ex.0.mean.tr"). Only existing text fields can be edited.
tools/publish_content.py applies the edits before publishing, so a regenerated file never goes out without them.

New items are recorded too ("op": "add"): a word, a grammar exercise (top-level lists) or a unit phrase (a list inside
an item: "parent": {"keyField": "id", "key": "a1-03", "path": "phrases"}). They are recognised by their identity
(IDENTITY below), so re-applying never adds them twice. Only items added here can be removed again.
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


# Learner languages: a missing translation (e.g. "ku" next to "en") can be added by an edit.
LANGS = ('tr', 'en', 'es', 'fr', 'it', 'ku', 'ar')


# What makes an added item the same item again (after a file was regenerated).
IDENTITY = {'words': ('de', 'type'), 'grammarItems': ('q',), 'phrases': ('de',), 'grammar': ('id',)}


def same(a, b, fields):
    return all(a.get(f) == b.get(f) for f in fields)


def target_list(data, collection, parent):
    """The list an item is added to: a top-level list, or a list inside one item of it."""
    items = data.get(collection)
    if not isinstance(items, list):
        raise ValueError(f'no list "{collection}"')
    if not parent:
        return items, collection
    owner = next((x for x in items if isinstance(x, dict) and x.get(parent['keyField']) == parent['key']), None)
    if owner is None or not isinstance(owner.get(parent['path']), list):
        raise ValueError(f'no list {parent["path"]} in {collection} {parent["key"]!r}')
    return owner[parent['path']], parent['path']


def place(data, collection, item, parent):
    """Adds the item unless it is already there. Words get the next free id. Returns the item as stored."""
    target, kind = target_list(data, collection, parent)
    fields = IDENTITY.get(kind, ())
    existing = next((x for x in target if fields and same(x, item, fields)), None)
    if existing is not None:
        return existing
    item = dict(item)
    if kind == 'words':
        item['id'] = max([w['id'] for w in target if isinstance(w.get('id'), int)] + [0]) + 1
    target.append(item)
    return item


def add(file, collection, item, parent=None):
    """Adds a new item to a content file and records it."""
    kind = parent['path'] if parent else collection
    fields = IDENTITY.get(kind)
    if not fields:
        raise ValueError(f'adding to {kind} is not supported')
    full, raw, data = read_file(file)
    target, _ = target_list(data, collection, parent)
    if any(same(x, item, fields) for x in target):
        raise ValueError('this item already exists')
    stored = place(data, collection, item, parent)
    write_file(full, raw, data)
    edits = load_edits()
    edits.append({'op': 'add', 'file': file, 'collection': collection, 'parent': parent, 'item': item,
                  'at': datetime.datetime.now().isoformat(timespec='seconds')})
    save_edits(edits)
    return stored


def remove(file, collection, item, parent=None):
    """Removes an item that was added in the Studio (and its record)."""
    kind = parent['path'] if parent else collection
    fields = IDENTITY.get(kind, ())
    edits = load_edits()
    record = next((e for e in edits if e.get('op') == 'add' and e['file'] == file and e['collection'] == collection and
                   e.get('parent') == parent and same(e['item'], item, fields)), None)
    if record is None:
        raise ValueError('only items added in the Studio can be removed')
    full, raw, data = read_file(file)
    target, _ = target_list(data, collection, parent)
    target[:] = [x for x in target if not same(x, item, fields)]
    write_file(full, raw, data)
    save_edits([e for e in edits if e is not record])


def added(file=None):
    return [e for e in load_edits() if e.get('op') == 'add' and (file is None or e['file'] == file)]


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
        if isinstance(node, dict) and last in LANGS and isinstance(node.get('en'), str):
            return node, last  # translation not there yet: it can be written
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
    old = node.get(last, '') if isinstance(node, dict) else node[last]
    if old == value:
        return old
    node[last] = value
    write_file(full, raw, data)
    def mine(e):
        return (e.get('op', 'set') == 'set' and e['file'] == file and e['collection'] == collection and
                e['keyField'] == key_field and e['key'] == key and e['path'] == path)
    edits = [e for e in load_edits() if not mine(e)]
    original = next((e['original'] for e in load_edits() if mine(e)), old)
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
    applied = already = 0
    failed = []
    for file, edits in by_file.items():
        try:
            full, raw, data = read_file(file)
        except (OSError, ValueError) as err:
            failed += [(e, str(err)) for e in edits]
            continue
        changed = False
        for e in edits:
            if e.get('op') == 'add':
                try:
                    target, kind = target_list(data, e['collection'], e.get('parent'))
                except ValueError as err:
                    failed.append((e, str(err)))
                    continue
                if any(same(x, e['item'], IDENTITY.get(kind, ())) for x in target):
                    already += 1
                else:
                    place(data, e['collection'], e['item'], e.get('parent'))
                    applied += 1
                    changed = True
                continue
            try:
                node, last = locate(data, e['collection'], e['keyField'], e['key'], e['path'])
            except ValueError as err:
                failed.append((e, str(err)))
                continue
            if (node.get(last) if isinstance(node, dict) else node[last]) == e['value']:
                already += 1
            else:
                node[last] = e['value']
                applied += 1
                changed = True
        if changed:
            write_file(full, raw, data)
    if not quiet:
        print(f'edits: {applied} applied, {already} already in place, {len(failed)} failed')
        for e, why in failed:
            print(f'  FAILED {e["file"]} {e["collection"]} {e.get("key", e.get("item"))}: {why}')
    return applied, already, failed


if __name__ == '__main__':
    if '--list' in sys.argv:
        for e in load_edits():
            if e.get('op') == 'add':
                print(f'{e["at"]}  {e["file"]} {e["collection"]} + {json.dumps(e["item"], ensure_ascii=False)[:90]}')
            else:
                print(f'{e["at"]}  {e["file"]} {e["collection"]}[{e["key"]}].{e["path"]}: {e["original"]!r} → {e["value"]!r}')
    else:
        apply_all()

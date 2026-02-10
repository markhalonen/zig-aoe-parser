import json

zig = json.load(open('output.json'))
py = json.load(open('aoc-mgz/output.txt'))

# Check if Python carries forward object_ids
prev_py_ids = None
for i in range(12, 30):
    if i >= len(py['actions']):
        break
    if py['actions'][i]['type'] != 'MOVE':
        continue
    pa = py['actions'][i]['payload']
    py_ids = pa.get('object_ids', [])
    carries = "SAME" if py_ids == prev_py_ids else "NEW"
    print(f'Action {i}: py_ids={py_ids} | {carries}')
    prev_py_ids = py_ids

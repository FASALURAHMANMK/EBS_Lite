import os
import re

# Collect struct definitions
structs = {}
models_dir = os.path.join('go_backend_rmt', 'internal', 'models')
for root, dirs, files in os.walk(models_dir):
    for f in files:
        if not f.endswith('.go'):
            continue
        path = os.path.join(root, f)
        with open(path) as fh:
            content = fh.read()
        for match in re.finditer(r'type\s+(\w+)\s+struct\s*\{([^}]*)\}', content, re.S):
            name = match.group(1)
            body = match.group(2)
            fields = []
            for line in body.splitlines():
                line = line.strip()
                if not line or line.startswith('//'):
                    continue
                m = re.match(r'(\w+)\s+([^`\s]+)(?:\s+`json:"([^"]+)"[^`]*`)?', line)
                if m:
                    field_name = m.group(3) if m.group(3) else m.group(1)
                    field_type = m.group(2)
                    fields.append((field_name, field_type))
            structs[name] = fields

# Read existing doc
DocPath = os.path.join('go_backend_rmt', 'Docs & Schema', 'API_DOCUMENTATION.md')
with open(DocPath, 'r') as fh:
    lines = fh.readlines()

out_lines = []
current_request = None
current_method = None
current_path = None

def infer_struct_from_path(path, method):
    if not path:
        return None
    segments = [seg for seg in path.strip('/').split('/') if seg and not seg.startswith(':')]
    if not segments:
        return None
    # remove api and version prefixes if present
    if segments[0] == 'api':
        segments = segments[2:]
    if not segments:
        return None
    name = segments[-1]
    if name.endswith('s'):
        name = name[:-1]
    name = ''.join(part.capitalize() for part in re.split('[-_]', name))
    # attempt variations
    candidates = [name, name + 'Response']
    for cand in candidates:
        if cand in structs:
            return cand
    return None

for i, line in enumerate(lines):
    out_lines.append(line)
    header = re.match(r'##\s+(\w+)\s+([^\s]+)', line)
    if header:
        current_method, current_path = header.group(1), header.group(2)
        continue
    # detect request struct
    m_req = re.match(r'\*\*(\w+)Request\*\*', line)
    if m_req:
        current_request = m_req.group(1)
        continue
    # When we encounter line with '- data (object)' inside response
    if line.strip() == '- data (object)':
        resp_name = None
        if current_request:
            cand = current_request + 'Response'
            if cand in structs:
                resp_name = cand
        if not resp_name:
            resp_name = infer_struct_from_path(current_path, current_method)
        if resp_name and resp_name in structs:
            out_lines[-1] = f'- data ({resp_name})\n'
            for fname, ftype in structs[resp_name]:
                out_lines.append(f'    - {fname} ({ftype})\n')
        current_request = None

with open(DocPath, 'w') as fh:
    fh.writelines(out_lines)

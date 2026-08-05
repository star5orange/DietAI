import rarfile, os

rf = rarfile.RarFile('skill.zip')
outdir = os.path.join(os.getcwd(), '.claude', 'skills')
os.makedirs(outdir, exist_ok=True)

for info in rf.infolist():
    path = info.filename.replace('\\', '/')
    parts = path.split('/')
    if len(parts) < 3:
        continue

    skill_name = parts[1]
    file_name = '/'.join(parts[2:])

    if not file_name:
        continue

    dest_dir = os.path.join(outdir, skill_name)
    dest_path = os.path.join(dest_dir, file_name)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)

    print(f'Extracting: {skill_name}/{file_name}')
    content = rf.read(path)
    with open(dest_path, 'wb') as f:
        f.write(content)

print(f'\nDone! Skills extracted to {outdir}')
for d in sorted(os.listdir(outdir)):
    print(f'\n  {d}/')
    for root, dirs, files in os.walk(os.path.join(outdir, d)):
        for f in sorted(files):
            rel = os.path.relpath(os.path.join(root, f), outdir)
            print(f'    {rel}')

os.remove('_extract_skills.py')

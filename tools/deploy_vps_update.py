"""Backup, apply an additive migration, and deploy the reviewed API archive.

Run as root on the existing VPS. Credentials come from the running service's
environment and are passed to PostgreSQL through environment variables only.
"""
import os
import argparse
from pathlib import Path
import subprocess
import sys
import tarfile
import time
from datetime import datetime, timezone

ROOT = Path('/opt/api-ludo')
ARCHIVE = Path('/tmp/ludo-api-update.tar.gz')
parser = argparse.ArgumentParser()
parser.add_argument('--code-only', action='store_true', help='Deploy reviewed code without changing dependencies or the database schema')
args = parser.parse_args()
pid = subprocess.check_output(['systemctl', 'show', 'api-ludo', '-p', 'MainPID', '--value'], text=True).strip()
for item in Path(f'/proc/{pid}/environ').read_bytes().split(b'\0'):
    if b'=' in item:
        key, value = item.split(b'=', 1)
        os.environ[key.decode()] = value.decode()
os.environ['PYTHONPATH'] = f'{ROOT}:{ROOT / "services/api"}'
sys.path.insert(0, str(ROOT / 'services/api'))
sys.path.insert(0, str(ROOT))
from sqlalchemy.engine import make_url

def run(args, **kwargs):
    subprocess.run(args, check=True, **kwargs)

stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
backups = Path('/opt/api-ludo-backups')
backups.mkdir(mode=0o700, exist_ok=True)
backups.chmod(0o700)
database_backup = backups / f'database-{stamp}.dump'
code_backup = backups / f'code-{stamp}.tar.gz'
url = make_url(os.environ['DATABASE_URL'])
assert url.get_backend_name() == 'postgresql', 'Expected the production PostgreSQL database'
pg_env = dict(os.environ, PGHOST=url.host or 'localhost', PGPORT=str(url.port or 5432),
    PGUSER=url.username or '', PGPASSWORD=url.password or '')
run(['pg_dump', '-Fc', '-f', str(database_backup), url.database], env=pg_env)
database_backup.chmod(0o600)
with tarfile.open(code_backup, 'w:gz') as backup:
    for name in ['services/api/app', 'services/api/alembic', 'services/api/requirements.txt', 'services/realtime']:
        backup.add(ROOT / name, arcname=name)
code_backup.chmod(0o600)
print('Backups saved:', database_backup, code_backup, flush=True)

with tarfile.open(ARCHIVE) as archive:
    for member in archive.getmembers():
        target = (ROOT / member.name).resolve()
        assert target.is_relative_to(ROOT) and not member.issym() and not member.islnk(), 'Unsafe archive member'
    archive.extractall(ROOT, filter='data')

python = str(ROOT / '.venv/bin/python')
try:
    if not args.code_only:
        run([python, '-m', 'pip', 'install', 'google-auth[requests]>=2.40.0'], stdout=subprocess.DEVNULL)
        run([python, '-m', 'alembic', 'upgrade', 'head'], cwd=ROOT / 'services/api')
    run(['systemctl', 'restart', 'api-ludo'])
    for attempt in range(30):
        result = subprocess.run(['curl', '--silent', '--fail', 'http://127.0.0.1:8000/health'], stdout=subprocess.DEVNULL)
        if result.returncode == 0:
            print('API restarted; health check passed.', flush=True)
            break
        time.sleep(1)
    else:
        raise RuntimeError('API health check failed')
except Exception:
    with tarfile.open(code_backup) as backup:
        backup.extractall(ROOT, filter='data')
    run(['systemctl', 'restart', 'api-ludo'])
    print('Previous API code restored. Additive database changes were retained.', flush=True)
    raise

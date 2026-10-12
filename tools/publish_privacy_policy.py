"""Publish static legal pages on the existing VPS without restarting the API.

Run as root after uploading rendered pages to /tmp/ludo-legal/. The exact Nginx
config and existing pages are backed up. A failed configuration check restores
the original files before Nginx is reloaded.
"""
from datetime import datetime, timezone
from pathlib import Path
import shutil
import subprocess

config = Path('/etc/nginx/sites-available/api-ludo.freefiremobile.space')
target = Path('/var/www/api-ludo/legal')
upload = Path('/tmp/ludo-legal')
stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
backup = Path('/opt/api-ludo-backups') / f'privacy-{stamp}'
backup.mkdir(mode=0o700, parents=True)
backup.chmod(0o700)
original = config.read_text()
shutil.copy2(config, backup / 'nginx.conf')
if target.exists():
    shutil.copytree(target, backup / 'legal')
target.mkdir(parents=True, exist_ok=True)
target.chmod(0o755)

headers = '''
        default_type text/html;
        charset utf-8;
        add_header X-Content-Type-Options nosniff always;
        add_header Referrer-Policy no-referrer always;
        add_header Content-Security-Policy "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'" always;
        add_header Cache-Control "public, max-age=300, no-transform" always;
'''
locations = '\n    # BEGIN LUDO LEGAL PAGES\n'
for route, filename in [('privacy-policy', 'privacy-policy.html'), ('delete-account', 'delete-account.html')]:
    page = (upload / filename).read_text(encoding='utf-8')
    assert ('CONTACT_PENDING' not in page and 'DRAFT — NOT PUBLISHED' not in page
            and 'Contact details awaiting confirmation' not in page and 'Ludo Play' in page), 'Policy contact is not ready'
    destination = target / filename
    destination.write_text(page, encoding='utf-8')
    destination.chmod(0o644)
    locations += f'    location = /{route} {{\n        alias {destination};{headers}    }}\n'
    locations += f'    location = /{route}/ {{ return 301 https://api-ludo.freefiremobile.space/{route}; }}\n'
locations += '    # END LUDO LEGAL PAGES\n\n'

def replace_legal(text):
    import re
    text = re.sub(r'\n    # BEGIN LUDO LEGAL PAGES.*?    # END LUDO LEGAL PAGES\n\n', '', text, flags=re.S)
    assert text.count('    location / {') == 2, 'Unexpected Nginx layout; inspect before editing'
    return text.replace('    location / {', locations + '    location / {')

try:
    config.write_text(replace_legal(original))
    subprocess.run(['nginx', '-t'], check=True)
    subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
except Exception:
    config.write_text(original)
    if (backup / 'legal').exists():
        shutil.copytree(backup / 'legal', target, dirs_exist_ok=True)
    subprocess.run(['nginx', '-t'], check=True)
    subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
    raise
print('Published static legal pages; API was not restarted. Backup:', backup)

import datetime
import subprocess
import sys
import os

tag = sys.argv[1]
version = tag.lstrip('v')
sha = os.environ.get('SHA256', '')
released = datetime.datetime.now().strftime('%Y-%m-%d')
url = f'https://github.com/toptestsoft/vyre-mobile/releases/download/{tag}/app-release.apk'
title = f'Version {version}'

# Get file size via curl
length = ''
try:
    size = subprocess.check_output(['curl', '-sI', url], text=True)
    for line in size.splitlines():
        if line.startswith('Content-Length'):
            length = line.split(':')[1].strip()
            break
except Exception:
    pass

length_attr = f'length="{length}"' if length else ''

xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://purl.org/rss/1.0/modules/sparkle/">
  <channel>
    <title>VYRE Mobile Updates</title>
    <link>https://github.com/toptestsoft/vyre-mobile</link>
    <description>Appcast feed for VYRE mobile application.</description>
    <language>en</language>
    <item>
      <title>{title}</title>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/toptestsoft/vyre-mobile/releases/tag/{tag}</sparkle:releaseNotesLink>
      <enclosure
        url="{url}"
        type="application/octet-stream"
        sparkle:version="{version}"
        sparkle:shortVersionString="{version}"
        sparkle:dsaSignature=""
        sparkle:ed25519Signature=""
        {length_attr}
        />
    </item>
  </channel>
</rss>'''

with open('appcast.xml', 'w') as f:
    f.write(xml)

print(f"✅ appcast.xml updated for {tag}")

"""Tambahkan izin & intent yang dibutuhkan Zaraa Party ke AndroidManifest hasil `flutter create`."""
import re, sys

p = 'app/android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()

perms = [
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.MODIFY_AUDIO_SETTINGS',
    'android.permission.BLUETOOTH',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.CHANGE_NETWORK_STATE',
]
add = ''.join(f'    <uses-permission android:name="{x}"/>\n' for x in perms if x not in s)
s = s.replace('<application', add + '    <application', 1)

# url_launcher (Android 11+): izinkan membuka https, mailto.
intents = (
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>\n'
)
if 'android:scheme="https"' not in s:
    if '</queries>' in s:
        s = s.replace('</queries>', intents + '    </queries>', 1)
    else:
        s = s.replace('</manifest>', '    <queries>\n' + intents + '    </queries>\n</manifest>', 1)

# Nama di layar HP.
s = re.sub(r'android:label="[^"]*"', 'android:label="Zaraa Party"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('AndroidManifest dipatch')

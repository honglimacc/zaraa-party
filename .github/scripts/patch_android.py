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

# Beberapa plugin masih dikompilasi dengan SDK lama; paksa semua library Android memakai SDK 36.
import os
for name, block in (
    ('android/build.gradle.kts', '''
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}
'''),
    ('android/build.gradle', '''
subprojects {
    afterEvaluate { project ->
        if (project.plugins.hasPlugin("com.android.library")) {
            project.android { compileSdkVersion 36 }
        }
    }
}
'''),
):
    gp = os.path.join('app', name)
    if os.path.exists(gp):
        g = open(gp, encoding='utf-8').read()
        # Harus didaftarkan sebelum blok evaluationDependsOn bawaan Flutter.
        marker = 'subprojects {'
        idx = g.find(marker)
        g = g[:idx] + block.lstrip('\n') + '\n' + g[idx:] if idx >= 0 else g + block
        open(gp, 'w', encoding='utf-8').write(g)
        print('compileSdk dipaksa 36 di', gp)
        break

# Tanda tangan release dengan keystore tetap (bila tersedia), supaya SHA-1 stabil untuk Google Sign-In & Play Store.
ks = os.environ.get('KEYSTORE_FILE')
gp = 'app/android/app/build.gradle.kts'
if ks and os.path.exists(gp):
    g = open(gp, encoding='utf-8').read()
    cfg = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_FILE"))
            storeType = "pkcs12"
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = "zaraa"
            keyPassword = System.getenv("KEYSTORE_PASSWORD")
        }
    }

'''
    g = g.replace('    buildTypes {', cfg + '    buildTypes {', 1)
    g = g.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    open(gp, 'w', encoding='utf-8').write(g)
    print('Release ditandatangani dengan keystore Zaraa')
else:
    print('PERINGATAN: keystore tidak tersedia, APK ditandatangani kunci debug (SHA-1 berubah-ubah)')

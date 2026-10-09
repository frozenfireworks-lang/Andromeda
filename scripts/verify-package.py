"""Fail packaging when an executable, arm64 slice, or original entitlement is missing."""
import pathlib, plistlib, subprocess, sys
app = pathlib.Path(sys.argv[1])
root = pathlib.Path(__file__).resolve().parent.parent
pairs = [(app / 'Geranium', root / 'entitlements.plist'),
         (app / 'GeraniumRootHelper', root / 'RootHelper/entitlements.plist'),
         (app / 'PlugIns/Bookmark Location in Geranium.appex/Bookmark Location in Geranium',
          root / 'Bookmark Location in Geranium/entitlements.plist')]
for executable, source in pairs:
    assert executable.is_file() and executable.stat().st_mode & 0o111, executable
    archs = subprocess.check_output(['lipo', '-archs', str(executable)], text=True)
    assert 'arm64' in archs.split(), (executable, archs)
    actual = plistlib.loads(subprocess.check_output(['ldid', '-e', str(executable)]))
    expected = plistlib.loads(source.read_bytes())
    assert actual == expected, f'Entitlements changed: {executable}'
    print(f'PASS: {executable.name}: arm64, executable, exact entitlements')
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert float(info['MinimumOSVersion']) <= 16, info['MinimumOSVersion']
assert (app/'GeraniumRootHelper').read_bytes() == (root/'Geranium/GeraniumRootHelper').read_bytes()
print('PASS: iOS 16 minimum OS and freshly built RootHelper verified')

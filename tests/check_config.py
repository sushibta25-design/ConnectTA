"""Static package checks; these do not simulate UIKit or device compatibility."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
source = (root / 'Tweak.xm').read_text()
config = (root / 'CTConfig.h').read_text()
prefs = (root / 'prefs/CTRootListController.m').read_text()
for path in (root / 'prefs/Resources/Info.plist', root / 'layout/Library/PreferenceLoader/Preferences/ConnectTA.plist'):
    with path.open('rb') as stream:
        plistlib.load(stream)
assert 'CTHomeIncludeApps' in source
assert 'CTIsYouTube' not in source
assert 'CTTryDirectLaunch' not in source and 'CTHostTick' not in source
assert 'gYouTubeLayout?1024.0:viewport.size.width' in source
assert re.search(r'if\(gYouTubeLayout\)\s*\{\s*%init\(CTTabletIdentity\)', source)
assert 'CTEligibleIdentifier(identifier)' in config
assert 'if(![stored isKindOfClass:NSArray.class])' in config
assert 'CFPreferencesSetValue(CFSTR("EnabledApps")' in prefs
assert 'notify_post(CTPreferencesChanged)' in prefs
assert 'CTReadPublishedEnabled(bundle,CTEnabled(bundle))' in source
assert 'if(spring)CTPublishEnabledApps' in source
assert 'com.apple.UIKitCore' in (root / 'ConnectTA.plist').read_text()
assert 'notify_register_dispatch(CTPreferencesChanged' in source
assert 'com.apple.UIKit' in (root / 'ConnectTA.plist').read_text()
assert 'SUBPROJECTS += prefs' in (root / 'Makefile').read_text()
assert 'preferenceloader' in (root / 'control').read_text()
workflow = (root / '.github/workflows/build.yml').read_text()
assert 'https://github.com/roothide/theos.git' in workflow
assert 'THEOS_PACKAGE_SCHEME=roothide' in workflow
for package in ('ROOTLESS', 'ROOTHIDE', 'ROOTFUL'):
    assert f'ConnectTA-${{CONNECTTA_VERSION}}-{package}.deb' in workflow

print('PASS: package config, per-app gating, legacy removal, and all three jailbreak build artifacts')


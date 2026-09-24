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
assert 'MSHookMessageEx' in source
assert 'method_setImplementation' not in source
assert 'class_replaceMethod' not in source
assert 'CTInstallAppClientObserver' not in source
assert 'requestSceneSessionActivation' not in source
assert 'CONNECTTA-0.4.2' in source
print('PASS: package plists, shared preferences, chained ObjC hooks, YouTube-only layout, legacy removal')


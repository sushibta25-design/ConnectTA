"""Static package checks; these do not simulate UIKit or device compatibility."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
source = (root / 'Tweak.xm').read_text()
config = (root / 'MTConfig.h').read_text()
prefs = (root / 'prefs/MTRootListController.m').read_text()
for path in (root / 'prefs/Resources/Info.plist', root / 'layout/Library/PreferenceLoader/Preferences/MiniTa.plist'):
    with path.open('rb') as stream:
        plistlib.load(stream)
assert 'MTHomeIncludeApps' in source
assert 'MTIsYouTube' not in source
assert 'MTTryDirectLaunch' not in source and 'MTHostTick' not in source
assert 'gYouTubeLayout?MTYouTubeLogicalWidth(viewport.size.width):viewport.size.width' in source
assert 'MTTabletIdentity' not in source
assert 'MTEligibleIdentifier(identifier)' in config
assert 'if(![stored isKindOfClass:NSArray.class])' in config
assert 'CFPreferencesSetValue(CFSTR("EnabledApps")' in prefs
assert 'notify_post(MTPreferencesChanged)' in prefs
assert 'MTReadPublishedEnabled(bundle,MTEnabled(bundle))' in source
assert 'if(spring)MTPublishEnabledApps' in source
assert 'com.apple.UIKitCore' in (root / 'MiniTa.plist').read_text()
assert 'notify_register_dispatch(MTPreferencesChanged' in source
assert 'com.apple.UIKit' in (root / 'MiniTa.plist').read_text()
assert 'SUBPROJECTS += prefs' in (root / 'Makefile').read_text()
assert 'preferenceloader' in (root / 'control').read_text()
print('PASS: package plists, shared preferences, per-app gating, YouTube-only layout, legacy removal')

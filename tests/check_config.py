"""Static package checks; these do not simulate UIKit or device compatibility."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
source = (root / 'Tweak.xm').read_text()
makefile = (root / 'Makefile').read_text()
netflix_filter = (root / 'ConnectTANetflix.plist').read_text()
config = (root / 'CTConfig.h').read_text()
prefs = (root / 'prefs/CTRootListController.m').read_text()
host = (root / 'CTExternalCarPlayHost.xm').read_text()
window = (root / 'CTExternalCarPlayWindow.mm').read_text()
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
assert 'ConnectTA_FILES = Tweak.xm' in makefile
assert 'ConnectTANetflix_FILES = CTExternalCarPlayHost.xm CTExternalCarPlayWindow.mm' in makefile
assert 'com.apple.CarPlayApp' in netflix_filter and 'com.apple.springboard' in netflix_filter
assert '[bundle isEqualToString:CTNetflixBundle] && CTNetflixEnabled()' in host
assert '%hook SpringBoard' not in host
assert '&& CTNetflixEnabled()) CTInstallSpringBoardObservers();' in host
assert '&& CTNetflixEnabled()) %init(CTCarPlayLaunch);' in host
assert 'CTExternalCarPlayHost' not in source
assert 'com.google.ios.youtube' not in host
assert 'com.netflix.Netflix' in host
assert 'requestSceneSessionActivation' not in source
assert 'CTHybridInstallAppBridge();return;' in source
assert 'UIRootSceneWindow' in window
assert 'SBAppViewController' in window
print('PASS: package plists, shared preferences, preserved ConnectTA path, and isolated Netflix host gate')


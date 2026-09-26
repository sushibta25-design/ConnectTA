from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "Tweak.xm").read_text()
filter_plist = (root / "NetflixDiag.plist").read_text()
makefile = (root / "Makefile").read_text()
assert 'com.netflix.Netflix' in filter_plist
assert 'com.apple.springboard' not in filter_plist
assert 'com.apple.CarPlayApp' not in filter_plist
assert 'TWEAK_NAME = NetflixDiag' in makefile
assert 'NetflixDiag_FILES = Tweak.xm' in makefile
assert 'UIScreenCapturedDidChangeNotification' in source
assert 'AVPlayerItemFailedToPlayToEndTimeNotification' in source
assert 'AVPlayerItemNewErrorLogEntryNotification' in source
assert 'error-log entries=' in source
assert 'NDLogPath=@"/var/mobile/NetflixDiag.log"' in source
assert '%hook ' not in source
assert 'requestSceneSessionActivation' not in source
assert 'FairPlay' not in source and 'HDCP' not in source
print("PASS: Netflix-only read-only diagnostics; no SpringBoard hooks or playback changes")

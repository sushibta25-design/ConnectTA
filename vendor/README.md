# Build-only Preferences stub

The trimmed iPhoneOS SDK used by CI lacks the private Preferences framework link stub.
This file declares only the classes/ivar used by ConnectTAPrefs, matching Theos headers.
It contains no implementation and is not installed on the device. At runtime the
PreferenceBundle links to Apple's system Preferences framework.


include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = ConnectTAPrefs
ConnectTAPrefs_FILES = CTRootListController.m
ConnectTAPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
ConnectTAPrefs_PRIVATE_FRAMEWORKS = Preferences
ConnectTAPrefs_LDFLAGS = -F$(abspath ../vendor)
ConnectTAPrefs_CFLAGS = -fobjc-arc
ConnectTAPrefs_INSTALL_PATH = /Library/PreferenceBundles
include $(THEOS_MAKE_PATH)/bundle.mk


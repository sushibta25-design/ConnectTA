ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ConnectTA
ConnectTA_FILES = Tweak.xm
ConnectTA_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ConnectTA_FRAMEWORKS = UIKit Foundation CoreFoundation
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk


ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MiniTaProbe
MiniTaProbe_FILES = Tweak.xm
MiniTaProbe_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MiniTaProbe_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk

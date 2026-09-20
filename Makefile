ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MiniTa
MiniTa_FILES = Tweak.xm
MiniTa_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MiniTa_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk

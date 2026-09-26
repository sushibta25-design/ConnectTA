ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = NetflixDiag
NetflixDiag_FILES = Tweak.xm
NetflixDiag_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
NetflixDiag_FRAMEWORKS = UIKit Foundation AVFoundation
include $(THEOS_MAKE_PATH)/tweak.mk

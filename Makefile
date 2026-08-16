ARCHS = arm64 arm64e
TARGET = iphone:clang:14.0:14.0
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ArtemisDiagnose
ArtemisDiagnose_FILES = Tweak.xm
ArtemisDiagnose_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

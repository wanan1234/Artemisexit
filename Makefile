ARCHS = arm64 arm64e
TARGET = iphone:clang:latest
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ArtemisDiagnose
ArtemisDiagnose_FILES = Tweak.xm
ArtemisDiagnose_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ArtemisDiagnose_PLIST = Artemis.plist   # 对应您的文件名

include $(THEOS_MAKE_PATH)/tweak.mk

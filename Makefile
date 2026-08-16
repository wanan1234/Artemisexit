ARCHS = arm64 arm64e
TARGET = iphone:clang:latest
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ArtemisAutoQuit
ArtemisAutoQuit_FILES = Tweak.xm
ArtemisAutoQuit_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ArtemisAutoQuit_PLIST = Artemis.plist   # 对应您的 plist 文件名

include $(THEOS_MAKE_PATH)/tweak.mk

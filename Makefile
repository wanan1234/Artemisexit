ARCHS = arm64 arm64e
TARGET = iphone:clang:latest
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ArtemisAutoQuit
ArtemisAutoQuit_FILES = Tweak.xm
ArtemisAutoQuit_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ArtemisAutoQuit_RESOURCES = Resources/catpaw.png

include $(THEOS_MAKE_PATH)/tweak.mk

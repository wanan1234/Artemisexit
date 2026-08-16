ARCHS = arm64 arm64e
TARGET = iphone:clang:latest
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ArtemisDiagnose
ArtemisDiagnose_FILES = Tweak.xm
ArtemisDiagnose_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# 将您的 Artemis.plist 复制为 Filter.plist，让 Theos 识别
before-stage::
	cp Artemis.plist Filter.plist || true

include $(THEOS_MAKE_PATH)/tweak.mk

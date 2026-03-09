THEOS_DEVICE_IP = localhost
TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MacroTweak

MacroTweak_FILES = Tweak.xm
MacroTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MacroTweak_FRAMEWORKS = UIKit CoreGraphics
MacroTweak_PRIVATE_FRAMEWORKS = 

# For jailed environment (LiveContainer compatible)
ifeq ($(JAILED),1)
    MacroTweak_EXTRA_FRAMEWORKS += CydiaSubstrate
    MacroTweak_LDFLAGS += -weak_framework CydiaSubstrate
endif

include $(THEOS_MAKE_PATH)/tweak.mk

# Fix install name for LiveContainer compatibility
after-install::
	install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).dylib || true

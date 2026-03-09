THEOS_DEVICE_IP = localhost
TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

# For jailed environment (LiveContainer compatible)
JAILED = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MacroTweak

MacroTweak_FILES = Tweak.xm
MacroTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MacroTweak_FRAMEWORKS = UIKit CoreGraphics

# Critical for LiveContainer: Use @rpath for CydiaSubstrate
ifeq ($(JAILED),1)
    MacroTweak_LDFLAGS += -F$(THEOS)/lib -framework CydiaSubstrate
    MacroTweak_LDFLAGS += -Wl,-rpath,@loader_path/Frameworks
    MacroTweak_LDFLAGS += -Wl,-rpath,@executable_path/Frameworks
    MacroTweak_LDFLAGS += -Wl,-rpath,@rpath
endif

include $(THEOS_MAKE_PATH)/tweak.mk

# Post-build: Fix install names for LiveContainer
after-all::
	@echo "Fixing rpath for LiveContainer compatibility..."
	install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate $(THEOS_OBJ_DIR)/MacroTweak.dylib || true
	install_name_tool -id @rpath/MacroTweak.dylib $(THEOS_OBJ_DIR)/MacroTweak.dylib || true
	@echo "Verifying rpath..."
	otool -L $(THEOS_OBJ_DIR)/MacroTweak.dylib | head -5

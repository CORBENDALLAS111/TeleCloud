# =============================================================================
# MacroTweak — Makefile
# Builds MacroTweak.dylib for arm64 iOS 16.2+
# Does NOT require Theos — uses xcrun clang + ldid directly
# =============================================================================

TWEAK_NAME   := MacroTweak
SOURCE        := Sources/MacroTweak.m
OUTPUT        := $(TWEAK_NAME).dylib

# ─── Toolchain (filled by xcrun) ─────────────────────────────────────────────
CLANG   := $(shell xcrun --sdk iphoneos -f clang 2>/dev/null || echo clang)
SDK     := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
LDID    := $(shell command -v ldid 2>/dev/null || echo ldid)

# ─── Architecture & deployment target ────────────────────────────────────────
ARCH_FLAGS    := -arch arm64
MIN_VERSION   := -miphoneos-version-min=16.2

# ─── Compile flags ───────────────────────────────────────────────────────────
CFLAGS := \
	-fobjc-arc \
	-fmodules \
	-fvisibility=hidden \
	-isysroot $(SDK) \
	$(ARCH_FLAGS) \
	$(MIN_VERSION) \
	-O2 \
	-Wall \
	-Wno-unused-function \
	-DTARGET_OS_IPHONE=1

# ─── Linker flags ────────────────────────────────────────────────────────────
# CydiaSubstrate is resolved at runtime via @rpath (placed next to the dylib).
# -undefined dynamic_lookup lets us link without a stub library.
LDFLAGS := \
	-dynamiclib \
	-isysroot $(SDK) \
	$(ARCH_FLAGS) \
	$(MIN_VERSION) \
	-install_name @rpath/$(OUTPUT) \
	-rpath @loader_path \
	-rpath @executable_path/Frameworks \
	-framework UIKit \
	-framework Foundation \
	-framework CoreGraphics \
	-undefined dynamic_lookup

# =============================================================================
.PHONY: all build sign clean info

all: build

build: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@echo "→ Compiling $(SOURCE)"
	$(CLANG) $(CFLAGS) $(LDFLAGS) -o $@ $^
	@echo "→ Built: $@"
	@file $@

# Sign with ldid (fake signature accepted by LiveContainer / jailbreaks)
sign: $(OUTPUT)
	@echo "→ Signing with ldid -S"
	$(LDID) -S $(OUTPUT)
	@echo "→ Signed: $(OUTPUT)"

# Combined target used by CI
release: build sign
	@echo "────────────────────────────────────────"
	@echo "  $(OUTPUT) built and signed"
	@otool -l $(OUTPUT) | grep -A 3 LC_RPATH || true
	@echo "────────────────────────────────────────"

clean:
	rm -f $(OUTPUT)

info:
	@echo "CLANG : $(CLANG)"
	@echo "SDK   : $(SDK)"
	@echo "LDID  : $(LDID)"
	@echo "OUTPUT: $(OUTPUT)"

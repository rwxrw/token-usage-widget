APP    := UsageMeter
BUNDLE := $(APP).app
BUILD  := .build/debug/$(APP)

.PHONY: all build bundle run clean kill

all: run

build:
	swift build

bundle: build
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(BUILD) $(BUNDLE)/Contents/MacOS/$(APP)
	@cp UsageMeter/Info.plist $(BUNDLE)/Contents/Info.plist
	@codesign --force --deep --sign - $(BUNDLE)
	@echo "  → $(BUNDLE) ready"

run: bundle
	@pkill -x $(APP) 2>/dev/null || true
	@sleep 0.3
	@open $(BUNDLE)
	@echo "  → $(APP) launched — look in your menu bar"

kill:
	@pkill -x $(APP) 2>/dev/null && echo "  → $(APP) stopped" || echo "  → $(APP) was not running"

clean:
	@rm -rf .build $(BUNDLE)
	@echo "  → cleaned"

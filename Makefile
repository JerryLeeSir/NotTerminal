PLIST :=
APP := dist/NotTerminal.app
VERSION ?= 0.1
BUILD_NUMBER ?= 1
CONFIGURATION ?= debug
BIN := .build/$(CONFIGURATION)/NotTerminal
RESOURCE_BUNDLE := .build/$(CONFIGURATION)/NotTerminal_NotTerminal.bundle
DMG := dist/NotTerminal-$(VERSION)-macOS.dmg
DMG_ROOT := dist/dmg-root

.PHONY: build app run dmg clean

build:
	swift build -c $(CONFIGURATION)

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/NotTerminal
	cp -R $(RESOURCE_BUNDLE) $(APP)/Contents/Resources/
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0"><dict>' \
		'<key>CFBundleExecutable</key><string>NotTerminal</string>' \
		'<key>CFBundleIdentifier</key><string>dev.mitchellh.notterminal</string>' \
		'<key>CFBundleName</key><string>NotTerminal</string>' \
		'<key>CFBundleDisplayName</key><string>NotTerminal</string>' \
		'<key>CFBundlePackageType</key><string>APPL</string>' \
		'<key>CFBundleShortVersionString</key><string>$(VERSION)</string>' \
		'<key>CFBundleVersion</key><string>$(BUILD_NUMBER)</string>' \
		'<key>LSMinimumSystemVersion</key><string>13.0</string>' \
		'<key>NSHighResolutionCapable</key><true/>' \
		'</dict></plist>' > $(APP)/Contents/Info.plist
	codesign --force -s - $(APP) 2>/dev/null || true

run: app
	open $(APP)

dmg:
	$(MAKE) app CONFIGURATION=release VERSION=$(VERSION) BUILD_NUMBER=$(BUILD_NUMBER)
	rm -rf $(DMG_ROOT)
	mkdir -p $(DMG_ROOT)
	ditto $(APP) $(DMG_ROOT)/NotTerminal.app
	ln -s /Applications $(DMG_ROOT)/Applications
	rm -f $(DMG)
	hdiutil create -volname "NotTerminal $(VERSION)" -srcfolder $(DMG_ROOT) -ov -format UDZO $(DMG)
	rm -rf $(DMG_ROOT)

clean:
	rm -rf .build dist

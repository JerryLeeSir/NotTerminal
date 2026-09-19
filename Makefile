PLIST :=
APP := dist/NotTerminal.app
BIN := .build/debug/NotTerminal

.PHONY: build app run clean

build:
	swift build -c debug

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/NotTerminal
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0"><dict>' \
		'<key>CFBundleExecutable</key><string>NotTerminal</string>' \
		'<key>CFBundleIdentifier</key><string>dev.mitchellh.notterminal</string>' \
		'<key>CFBundleName</key><string>NotTerminal</string>' \
		'<key>CFBundleDisplayName</key><string>NotTerminal</string>' \
		'<key>CFBundlePackageType</key><string>APPL</string>' \
		'<key>CFBundleShortVersionString</key><string>0.1.0</string>' \
		'<key>CFBundleVersion</key><string>1</string>' \
		'<key>LSMinimumSystemVersion</key><string>13.0</string>' \
		'<key>NSHighResolutionCapable</key><true/>' \
		'</dict></plist>' > $(APP)/Contents/Info.plist
	codesign --force -s - $(APP) 2>/dev/null || true

run: app
	open $(APP)

clean:
	rm -rf .build dist
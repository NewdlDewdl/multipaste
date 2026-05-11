.PHONY: all build test install uninstall purge run clean status logs

all: build

test:
	swift run -c debug MultipasteTests

build:
	bash scripts/build.sh

install: build
	bash scripts/install.sh

uninstall:
	bash scripts/uninstall.sh

purge:
	bash scripts/uninstall.sh --purge

run: build
	./dist/Multipaste.app/Contents/MacOS/Multipaste

status:
	@launchctl list | grep com.rohin.multipaste || echo "not running"
	@echo
	@ls -la ~/Library/LaunchAgents/com.rohin.multipaste.plist 2>/dev/null || true

logs:
	@tail -n 80 -F ~/Library/Logs/Multipaste/multipaste.err.log ~/Library/Logs/Multipaste/multipaste.out.log

clean:
	rm -rf .build dist

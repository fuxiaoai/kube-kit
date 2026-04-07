.PHONY: all package clean st

# Target name
TARGET = kube-kit.tar.gz

all: package

package: clean
	@echo "Packaging kube-kit into $(TARGET)..."
	@tar -czvf $(TARGET) kk lib/
	@echo "✅ Package created: $(TARGET)"
	@echo "You can now use $(TARGET) for standalone or henv distribution."

st: package
	@echo "Building standalone installer..."
	@bash build_standalone_installer.sh
	@if command -v pbcopy >/dev/null 2>&1; then \
		cat standalone_install.sh | pbcopy; \
		echo "✅ standalone_install.sh content copied to clipboard!"; \
	elif command -v xclip >/dev/null 2>&1; then \
		cat standalone_install.sh | xclip -selection clipboard; \
		echo "✅ standalone_install.sh content copied to clipboard!"; \
	else \
		echo "⚠️ pbcopy/xclip not found, could not copy to clipboard automatically."; \
	fi

clean:
	@echo "Cleaning up..."
	@rm -f $(TARGET) standalone_install.sh

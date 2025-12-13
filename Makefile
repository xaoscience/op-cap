all: build

build:
	gcc scripts/usbreset.c -o scripts/usbreset || true
	chmod +x scripts/*.sh || true
	chmod +x ffmpeg/*.sh || true

install: build
	sudo ./scripts/install.sh

optimise-drivers:
	sudo ./scripts/optimise_drivers.sh --auto

install-with-drivers: build optimise-drivers
	sudo ./scripts/install.sh

uninstall:
	@sudo ./scripts/uninstall.sh || true

clean:
	rm -f scripts/usbreset

distclean: clean uninstall

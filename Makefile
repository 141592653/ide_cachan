DEBUG_OPTION=-g
SOURCE_DIR=src/
BUILD_DIR=debug/
BUILD=ocamlbuild \
	  -build-dir "$(BUILD_DIR)" \
	  -cflags "$(DEBUG_OPTION)" \
	  -package lablgtk2 \
	  $(SOURCE_DIR)ide.native

default:
	-rm ide.debug
	$(BUILD)
	ln -s $(BUILD_DIR)$(SOURCE_DIR)ide.native ide.debug
release:
	DEBUG_OPTION=
	BUILD_DIR=release/
	-rm ide.release
	$(BUILD)
	ln -s $(BUILD_DIR)$(SOURCE_DIR)ide.native ide.release

clean:
	ocamlbuild -clean

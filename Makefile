# Theos build for iYMLegacy (legacy iOS application)
# Requires an iPhoneOS 6.1 SDK installed in Theos' SDK directory.

TARGET := iphone:clang:6.1:6.0
ARCHS := armv7
PACKAGE_FORMAT := ipa
FINALPACKAGE ?= 1
# The dpkg of iOS 6 era jailbreaks is happiest with gzip (for PACKAGE_FORMAT=deb).
THEOS_PLATFORM_DEB_COMPRESSION_TYPE := gzip

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := iYMLegacy

# Objective-C application sources plus the C Yandex/API implementation.
iYMLegacy_FILES = \
    src/main.m \
    src/AppDelegate.m \
    src/RootViewController.m \
    src/Item.m \
    src/FeedViewController.m \
    src/FavoritesViewController.m \
    src/SearchViewController.m \
    src/SearchViewControllerDetail.m \
    src/YandexConnect.m \
    src/TrackListViewController.m \
    src/PlayerViewController.m \
    src/RecentsViewController.m \
    src/PlayerController.m \
    src/PlaylistsViewController.m \
    src/TextEditViewController.m \
    src/ActionSheet.m \
    cYandexMusic/cYandexOAuth.c \
    cYandexMusic/cYandexMusic.c \
    cYandexMusic/md5.c \
    cYandexMusic/oauth.c \
    cYandexMusic/structures.c \
    cYandexMusic/uuid4.c \
    cYandexMusic/cJSON.c \
    cYandexMusic/ezxml.c

# The old project was ARC-based.
iYMLegacy_CFLAGS = \
    -fobjc-arc \
    -I$(THEOS_PROJECT_DIR)/src \
    -I$(THEOS_PROJECT_DIR)/cYandexMusic \
    -Wno-deprecated-declarations \
    -Wno-gnu-statement-expression

# Needed for old Clang/SDK combinations used by the project.
iYMLegacy_OBJCFLAGS = -fobjc-arc

# Frameworks used by the application.
iYMLegacy_FRAMEWORKS = \
    UIKit \
    Foundation \
    CoreGraphics \
    CoreMedia \
    AVFoundation \
    MediaPlayer \
    QuickLook

# Keep the legacy bundled curl/SSL libraries used by the original project.
iYMLegacy_LDFLAGS = \
    -L$(THEOS_PROJECT_DIR)/libs \
    -Wl,-rpath,@executable_path/libs \
    -Wl,-allow_sub_type_mismatches

iYMLegacy_LIBRARIES = curl ssl crypto

# Copy the original application resources into the .app bundle.
iYMLegacy_RESOURCE_FILES = src/Info.plist

iYMLegacy_RESOURCE_DIRS = \
    images \
    lproj \
    nibs

# The legacy dylibs are bundled inside iYMLegacy.app/libs.
# The old binaries use absolute /usr/lib install names, so rewrite them after
# staging.  The helper resolves install_name_tool from the legacy toolchain.
after-stage::
	@/bin/sh "$(THEOS_PROJECT_DIR)/tools/patch-install-names.sh" "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app"

# Info.plist carries VERSION placeholders (the autotools build seds them);
# fill them in from the control file.
after-stage::
	@sed -i 's/>VERSION</>$(THEOS_PACKAGE_BASE_VERSION)</g' "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/Info.plist"

# install_name_tool invalidates the signatures of the executable and of the
# bundled dylibs it rewrote: sign them again, the way Theos signed the binary.
after-stage::
	@for f in "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/libs/"*.dylib \
		"$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/iYMLegacy"; do \
		$(TARGET_CODESIGN) $(TARGET_CODESIGN_FLAGS) "$$f" || exit 1; \
	done

# Verify the app actually contains the dylibs after staging.
after-stage::
	@test -x "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/iYMLegacy"
	@test -f "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/libs/libcurl.dylib"
	@test -f "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/libs/libssl.dylib"
	@test -f "$(THEOS_STAGING_DIR)/Applications/iYMLegacy.app/libs/libcrypto.dylib"

after-package::
	@echo "iYMLegacy package: $(THEOS_PACKAGE_DIR)"

include $(THEOS_MAKE_PATH)/application.mk

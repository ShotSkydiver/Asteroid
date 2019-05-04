SDKVERSION = 11.2
ARCHS = arm64 arm64e
TARGET = iphone:clang:11.2:10.3

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Asteroid
Asteroid_FILES = $(wildcard source/*.m source/*.xm source/*.mm source/*.x source/SetupWindow/*.m source/SetupWindow/*.xm source/SetupWindow/*.x)
$(TWEAK_NAME)_FRAMEWORKS = CoreLocation 
$(TWEAK_NAME)_LIBRARIES = rocketbootstrap
$(TWEAK_NAME)_EXTRA_FRAMEWORKS = AsteroidSetup
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Weather WeatherUI AppSupport
$(TWEAK_NAME)_CFLAGS += -fobjc-arc -I$(THEOS_PROJECT_DIR)/source
$(TWEAK_NAME)_LDFLAGS += -lCSPreferencesProvider 

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += preferences
SUBPROJECTS += asteroidlockscreen
SUBPROJECTS += asteroidstatusbar
SUBPROJECTS += defaultweather
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"

#!/usr/bin/env python
import Command
import recalboxFiles
from generators.Generator import Generator
import dolphinControllers
import dolphinSYSCONF
import shutil
import os.path
from os import environ
import ConfigParser

class DolphinGenerator(Generator):

    def generate(self, system, rom, playersControllers, gameResolution):
        if not os.path.exists(os.path.dirname(recalboxFiles.dolphinIni)):
            os.makedirs(os.path.dirname(recalboxFiles.dolphinIni))

        dolphinControllers.generateControllerConfig(system, playersControllers, rom)

        # dolphin.ini
        dolphinSettings = ConfigParser.ConfigParser()
        # To prevent ConfigParser from converting to lower case
        dolphinSettings.optionxform = str
        if os.path.exists(recalboxFiles.dolphinIni):
            dolphinSettings.read(recalboxFiles.dolphinIni)

        # sections
        if not dolphinSettings.has_section("General"):
            dolphinSettings.add_section("General")
        if not dolphinSettings.has_section("Core"):
            dolphinSettings.add_section("Core")
        if not dolphinSettings.has_section("Interface"):
            dolphinSettings.add_section("Interface")
        if not dolphinSettings.has_section("Analytics"):
            dolphinSettings.add_section("Analytics")

        # draw or not FPS
	if system.config['showFPS'] == 'true':
            dolphinSettings.set("General", "ShowLag", "True")
            dolphinSettings.set("General", "ShowFrameCount", "True")
        else:
            dolphinSettings.set("General", "ShowLag", "False")
            dolphinSettings.set("General", "ShowFrameCount", "False")

        # don't ask about statistics
        dolphinSettings.set("Analytics", "PermissionAsked", "True")

        # don't confirm at stop
        dolphinSettings.set("Interface", "ConfirmStop", "False")

        # language (for gamecube at least)
        dolphinSettings.set("Core", "SelectedLanguage", getGameCubeLangFromEnvironment())
        dolphinSettings.set("Core", "GameCubeLanguage", getGameCubeLangFromEnvironment())

        # wiimote scanning
        dolphinSettings.set("Core", "WiimoteContinuousScanning", "True")

        # gamecube pads forced as standard pad
        dolphinSettings.set("Core", "SIDevice0", "6")
        dolphinSettings.set("Core", "SIDevice1", "6")
        dolphinSettings.set("Core", "SIDevice2", "6")
        dolphinSettings.set("Core", "SIDevice3", "6")

        # save dolphin.ini
        with open(recalboxFiles.dolphinIni, 'w') as configfile:
            dolphinSettings.write(configfile)

        # gfx.ini
        dolphinGFXSettings = ConfigParser.ConfigParser()
        # To prevent ConfigParser from converting to lower case
        dolphinGFXSettings.optionxform = str
        dolphinGFXSettings.read(recalboxFiles.dolphinGfxIni)

        if not dolphinGFXSettings.has_section("Settings"):
            dolphinGFXSettings.add_section("Settings")
        dolphinGFXSettings.set("Settings", "AspectRatio", getGfxRatioFromConfig(system.config, gameResolution))

        # save gfx.ini
        with open(recalboxFiles.dolphinGfxIni, 'w') as configfile:
            dolphinGFXSettings.write(configfile)

        # update SYSCONF
        try:
            dolphinSYSCONF.update(system.config, recalboxFiles.dolphinSYSCONF, gameResolution)
        except Exception:
            pass # don't fail in case of SYSCONF update

        commandArray = [recalboxFiles.recalboxBins[system.config['emulator']], "-e", rom]
        return Command.Command(array=commandArray, env={"XDG_CONFIG_HOME":recalboxFiles.CONF, "XDG_DATA_HOME":recalboxFiles.SAVES})

def getGfxRatioFromConfig(config, gameResolution):
    # 2: 4:3 ; 1: 16:9  ; 0: auto
    if "ratio" in config:
        if config["ratio"] == "4/3":
            return 2
        if config["ratio"] == "16/9":
            return 1
    return 0

# seem to be only for the gamecube. However, while this is not in a gamecube section
# it may be used for something else, so set it anyway

def getGameCubeLangFromEnvironment():
    lang = environ['LANG'][:5]
    availableLanguages = { "en_US": 0, "de_DE": 1, "fr_FR": 2, "es_ES": 3, "it_IT": 4, "nl_NL": 5 }
    if lang in availableLanguages:
        return availableLanguages[lang]
    else:
        return availableLanguages["en_US"]

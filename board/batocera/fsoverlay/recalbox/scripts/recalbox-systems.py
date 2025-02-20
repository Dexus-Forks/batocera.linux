#!/usr/bin/env python

from hashlib import md5
from os.path import isfile
from collections import OrderedDict
import sys

systems = {

    # Atari
    "atari5200": { "name": "Atari 5200", "biosFiles": [ { "md5": "281f20ea4320404ec820fb7ec0693b38", "file": "bios/5200.rom"          },
                                                        { "md5": "06daac977823773a3eea3422fd26a703", "file": "bios/ATARIXL.ROM"       },
										                { "md5": "0bac0c6a50104045d902df4503a4c30b", "file": "bios/ATARIBAS.ROM"      },
                                                        { "md5": "eb1f32f5d9f382db1bbfb8d7f9cb343a", "file": "bios/ATARIOSA.ROM"      },
                                                        { "md5": "a3e8d617c95d08031fe1b20d541434b2", "file": "bios/ATARIOSB.ROM"      } ] },
	"atari7800": { "name": "Atari 7800", "biosFiles": [ { "md5": "397bb566584be7b9764e7a68974c4263", "file": "bios/7800 BIOS (E).rom" },
														{ "md5": "0763f1ffb006ddbe32e52d497ee848ae", "file": "bios/7800 BIOS (U).rom" },
														{ "md5": "ce6a86574d0c9de9075705f14e99d090", "file": "bios/ProSystem.dat"     } ] },
    "atarist":   { "name": "Atari ST", "biosFiles":   [ { "md5": "b2a8570de2e850c5acf81cb80512d9f6", "file": "bios/tos.img"           } ] },
    "lynx":      { "name": "Lynx", "biosFiles":       [ { "md5": "fcd403db69f54290b51035d82f835e7b", "file": "bios/lynxboot.img"	  } ] },


    # Commodore
	"amiga500":  { "name": "Amiga500",	"biosFiles":  [ { "md5": "82a21c1890cae844b3df741f2762d48d", "file": "bios/Kickstart v1.3 r34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV)[!].rom" } ] },
    "amiga500p": { "name": "Amiga500+", "biosFiles":  [ { "md5": "dc10d7bdd1b6f450773dfb558477c230", "file": "bios/Kickstart v2.04 r37.175 (1991)(Commodore)(A500+)[!].rom"              } ] },
    "amiga600":  { "name": "Amiga600",  "biosFiles":  [ { "md5": "465646c9b6729f77eea5314d1f057951", "file": "bios/Kickstart v2.05 r37.350 (1992)(Commodore)(A600HD)[!].rom"             } ] },
    "amiga1000": { "name": "Amiga1000", "biosFiles":  [ { "md5": "85ad74194e87c08904327de1a9443b7a", "file": "bios/Kickstart v1.2 r33.180 (1986)(Commodore)(A500-A1000-A2000)[!].rom"    } ] },
    "amiga1200": { "name": "Amiga1200", "biosFiles":  [ { "md5": "646773759326fbac3b2311fd8c8793ee", "file": "bios/Kickstart v3.1 r40.68 (1993)(Commodore)(A1200)[!].rom"                } ] },
    "amiga3000": { "name": "Amiga3000", "biosFiles":  [ { "md5": "413590e50098a056cfec418d3df0212d", "file": "bios/Kickstart v3.1 r40.68 (1993)(Commodore)(A3000).rom"                   } ] },
    "amiga4000": { "name": "Amiga4000", "biosFiles":  [ { "md5": "9bdedde6a4f33555b4a270c8ca53297d", "file": "bios/Kickstart v3.1 r40.68 (1993)(Commodore)(A4000).rom"                   } ] },
    "amigacd32": { "name": "Amiga CD32", "biosFiles": [ { "md5": "5f8924d013dd57a89cf349f4cdedc6b1", "file": "bios/Kickstart v3.1 r40.60 (1993)(Commodore)(CD32).rom"                    },
                                                        { "md5": "bb72565701b1b6faece07d68ea5da639", "file": "bios/CD32 Extended-ROM r40.60 (1993)(Commodore)(CD32).rom"                 } ] },
    "amigacdtv": { "name": "Amiga CDTV", "biosFiles": [ { "md5": "82a21c1890cae844b3df741f2762d48d", "file": "bios/Kickstart v1.3 r34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV)[!].rom" },
                                                        { "md5": "89da1838a24460e4b93f4f0c5d92d48d", "file": "bios/CDTV Extended-ROM v1.0 (1991)(Commodore)(CDTV)[!].rom"                } ] },


    # Magnavox and Philips
	"o2em": { "name": "Odyssey 2", "biosFiles": [ { "md5": "562d5ebf9e030a40d6fabfc2f33139fd", "file": "bios/o2rom.bin" },
												  { "md5": "f1071cdb0b6b10dde94d3bc8a6146387", "file": "bios/c52.bin"   },
												  { "md5": "c500ff71236068e0dc0d0603d265ae76", "file": "bios/g7400.bin" },
												  { "md5": "279008e4a0db2dc5f1c048853b033828", "file": "bios/jopac.bin" } ] },


    # Mattel
    "intellivision": { "name": "Mattel Intellivision", "biosFiles": [ { "md5": "62e761035cb657903761800f4437b8af", "file": "bios/exec.bin"   },
																	  { "md5": "0cd5946c6473e42e8e4c2137785e427f", "file": "bios/grom.bin"   },
																	  { "md5": "2e72a9a2b897d330a35c8b07a6146c52", "file": "bios/ECS.bin"    },
																	  { "md5": "d5530f74681ec6e0f282dab42e6b1c5f", "file": "bios/IVOICE.bin" } ] },


    # Microsoft
    "msx": { "name": "MSX", "biosFiles": [ { "md5": "364a1a579fe5cb8dba54519bcfcdac0d", "file": "bios/MSX.ROM"      },
										   { "md5": "ec3a01c91f24fbddcbcab0ad301bc9ef", "file": "bios/MSX2.ROM"     },
										   { "md5": "2183c2aff17cf4297bdb496de78c2e8a", "file": "bios/MSX2EXT.ROM"  },
										   { "md5": "847cc025ffae665487940ff2639540e5", "file": "bios/MSX2P.ROM"    },
										   { "md5": "7c8243c71d8f143b2531f01afa6a05dc", "file": "bios/MSX2PEXT.ROM" },
										   { "md5": "80dcd1ad1a4cf65d64b7ba10504e8190", "file": "bios/DISK.ROM"	    },
										   { "md5": "6f69cc8b5ed761b03afd78000dfb0e19", "file": "bios/FMPAC.ROM"    },
										   { "md5": "6418d091cd6907bbcf940324339e43bb", "file": "bios/MSXDOS2.ROM"  },
										   { "md5": "403cdea1cbd2bb24fae506941f8f655e", "file": "bios/PAINTER.ROM"  },
										   { "md5": "febe8782b466d7c3b16de6d104826b34", "file": "bios/KANJI.ROM"    } ] },


    # NEC
	"pcengine":   { "name": "PC Engine", "biosFiles":  [ { "md5": "ff1a674273fe3540ccef576376407d1d", "file": "bios/syscard3.pce" } ] },
    "pcfx":       { "name": "PC-FX", "biosFiles":      [ { "md5": "08e36edbea28a017f79f8d4f7ff9b6d7", "file": "bios/pcfx.rom"     } ] },
    "supergrafx": { "name": "Supergrafx", "biosFiles": [ { "md5": "ff1a674273fe3540ccef576376407d1d", "file": "bios/syscard3.pce" },
														 { "md5": "", "file": "bios/syscard2.pce"								  },
														 { "md5": "", "file": "bios/syscard1.pce"								  },
														 { "md5": "", "file": "bios/gexpress.pce"								  } ] },


    # Nintendo
	"fds": { "name": "Nintendo Family Computer Disk System", "biosFiles": [ { "md5": "7bfe8c0540ed4bd6a0f1e2a0f0118ced", "file": "bios/NstDatabase.xml" },
																		    { "md5": "ca30b50f880eb660a320674ed365ef7a", "file": "bios/disksys.rom"     } ] },
	"gb":  { "name": "Game Boy", "biosFiles":                             [ { "md5": "32fbbd84168d3482956eb3c5051637f5", "file": "bios/gb_bios.bin"  	},
											                                { "md5": "dbfce9db9deaa2567f6a84fde55f9680", "file": "bios/gbc_bios.bin" 	} ] },
	"gbc": { "name": "Game Boy Color", "biosFiles":                       [ { "md5": "32fbbd84168d3482956eb3c5051637f5", "file": "bios/gb_bios.bin"  	},
													                        { "md5": "dbfce9db9deaa2567f6a84fde55f9680", "file": "bios/gbc_bios.bin" 	} ] },
    "gba": { "name": "Game Boy Advance", "biosFiles":                     [ { "md5": "a860e8c0b6d573d191e4ec7db1b1e4f6", "file": "bios/gba_bios.bin" 	},
														                    { "md5": "32fbbd84168d3482956eb3c5051637f5", "file": "bios/gb_bios.bin"  	},
														                    { "md5": "dbfce9db9deaa2567f6a84fde55f9680", "file": "bios/gbc_bios.bin" 	},
														                    { "md5": "d574d4f9c12f305074798f54c091a8b4", "file": "bios/sgb_bios.bin" 	} ] },
    "nds": { "name": "Nintendo DS", "biosFiles":                          [ { "md5": "145eaef5bd3037cbc247c213bb3da1b3", "file": "bios/firmware.bin" 	},
												                            { "md5": "df692a80a5b1bc90728bc3dfc76cd948", "file": "bios/bios7.bin"    	},
												                            { "md5": "a392174eb3e572fed6447e956bde4b25", "file": "bios/bios9.bin"    	} ] },


    # Panasonic, Sanyo and Goldstar
    "3do":	{ "name": "3DO", "biosFiles": [ { "md5": "f47264dd47fe30f73ab3c010015c155b", "file": "bios/panafz1.bin"			},
											{ "md5": "51f2f43ae2f3508a14d9f56597e2d3ce", "file": "bios/panafz10.bin"		},
											{ "md5": "8639fd5e549bd6238cfee79e3e749114", "file": "bios/goldstar.bin"		},
											{ "md5": "35fa1a1ebaaeea286dc5cd15487c13ea", "file": "bios/sanyotry.bin"		},
											{ "md5": "8970fc987ab89a7f64da9f8a8c4333ff", "file": "bios/3do_arcade_saot.bin" } ] },


    # PrBoom Team
    "prboom": { "name": "Doom (PrBoom)", "biosFiles": [ { "md5": "", "file": "roms/prboom/prboom.wad" } ] },


    # Sega
    "dreamcast":    { "name": "Dreamcast", "biosFiles":    [ { "md5": "e10c53c2f8b90bab96ead2d368858623", "file": "bios/dc_boot.bin"   	  },
													         { "md5": "0a93f7940c455905bea6e392dfde92a4", "file": "bios/dc_flash.bin"  	  },
													         { "md5": "4bffb9b29b9aeb29aa618f3891a300ce", "file": "bios/dc_nvmem.bin"  	  } ] },
    "gamegear":     { "name": "Game Gear", "biosFiles":    [ { "md5": "672e104c3be3a238301aceffc3b23fd6", "file": "bios/bios.gg" 	   	  } ] },
    "mastersystem": { "name": "MasterSystem", "biosFiles": [ { "md5": "840481177270d5642a14ca71ee72844c", "file": "bios/bios_E.sms"    	  },
															 { "md5": "840481177270d5642a14ca71ee72844c", "file": "bios/bios_U.sms"    	  },
															 { "md5": "24a519c53f67b00640d0048ef7089105", "file": "bios/bios_J.sms"    	  } ] },
    "sega32x":      { "name": "Sega 32x", "biosFiles":     [ { "md5": "e66fa1dc5820d254611fdcdba0662372", "file": "bios/bios_CD_E.bin" 	  },
													         { "md5": "854b9150240a198070150e4566ae1290", "file": "bios/bios_CD_U.bin" 	  },
													         { "md5": "278a9397d192149e84e820ac621a8edd", "file": "bios/bios_CD_J.bin"	  } ] },
    "saturn":       { "name": "Sega Saturn", "biosFiles":  [ { "md5": "af5828fdff51384f99b3c4926be27762", "file": "bios/saturn_bios.bin"  },
													         { "md5": "85ec9ca47d8f6807718151cbcca8b964", "file": "bios/sega_101.bin"	  },
													         { "md5": "3240872c70984b6cbfda1586cab68dbe", "file": "bios/mpr-17933.bin"	  },
													         { "md5": "255113ba943c92a54facd25a10fd780c", "file": "bios/mpr-18811-mx.ic1" },
													         { "md5": "1cd19988d1d72a3e7caa0b73234c96b4", "file": "bios/mpr-19367-mx.ic1" },
													         { "md5": "53a094ad3a188f86de4e64624fe9b3ca", "file": "bios/stvbios.zip"	  } ] },
    "segacd":       { "name": "Sega CD", "biosFiles":      [ { "md5": "e66fa1dc5820d254611fdcdba0662372", "file": "bios/bios_CD_E.bin" 	  },
												             { "md5": "854b9150240a198070150e4566ae1290", "file": "bios/bios_CD_U.bin" 	  },
												             { "md5": "278a9397d192149e84e820ac621a8edd", "file": "bios/bios_CD_J.bin" 	  } ] },
    "naomi":        { "name": "Naomi", "biosFiles":        [ { "md5": "3bffafac42a7767d8dcecf771f5552ba", "file": "bios/naomi_boot.bin"   } ] },


    # Sharp
    "x68000": { "name": "Sharp x68000", "biosFiles": [ { "md5": "", "file": "bios/keropi/iplrom.dat"   },
													   { "md5": "", "file": "bios/keropi/iplrom30.dat" },
													   { "md5": "", "file": "bios/keropi/iplromco.dat" },
													   { "md5": "", "file": "bios/keropi/iplromxv.dat" },
													   { "md5": "", "file": "bios/keropi/cgrom.dat"	   } ] },


    # SNES
    "satellaview": { "name": "Satellaview", "biosFiles": [ { "md5": "fed4d8242cfbed61343d53d48432aced", "file": "bios/BS-X.bin"   } ] },
    "snes":        { "name": "SNES", "biosFiles":        [ { "md5": "d3a44ba7d42a74d3ac58cb9c14c6a5ca", "file": "bios/STBIOS.bin" } ] },

    # SNK
	"neogeo":   { "name": "NeoGeo", "biosFiles":    [ { "md5": "", "file": "roms/neogeo/neogeo.zip" } ] },
	"neogeocd": { "name": "NeoGeo CD", "biosFiles": [ { "md5": "", "file": "roms/neogeocd/neogeo.zip" },
													  { "md5": "", "file": "roms/neogeocd/neocdz.zip" }	] },


    # Sony Computer Entertainment
    "psx": { "name": "PSX", "biosFiles": [ { "md5": "8dd7d5296a650fac7319bce665a6a53c", "file": "bios/scph5500.bin"   },
										   { "md5": "490f666e1afb15b7362b406ed1cea246", "file": "bios/scph5501.bin"   },
										   { "md5": "32736f17079d0b2b7024407c39bd3050", "file": "bios/scph5502.bin"   } ] },
    "ps2": { "name": "PS2", "biosFiles": [ { "md5": "28922c703cc7d2cf856f177f2985b3a9", "file": "bios/SCPH30004R.bin" },
										   { "md5": "ea592129bf0c9189cafe772657261148", "file": "bios/SCPH30004R.NVM" },
										   { "md5": "3faf7c064a4984f53e2ef5e80ed543bc", "file": "bios/SCPH30004R.MEC" },
										   { "md5": "d5ce2c7d119f563ce04bc04dbc3a323e", "file": "bios/scph39001.bin"  },
										   { "md5": "0639a9ff5f5f3fd7833b924b9d97a8ae", "file": "bios/scph39001.NVM"  },
										   { "md5": "3faf7c064a4984f53e2ef5e80ed543bc", "file": "bios/scph39001.MEC"  },
										   { "md5": "9a9e8ed7668e6adfc8f7766c08ab9cd0", "file": "bios/EROM.BIN" 	  },
										   { "md5": "44552702b05697a14ccbe2ca22ee7139", "file": "bios/rom1.bin" 	  },
										   { "md5": "b406d05922dac2eaf3c2e68157b1b468", "file": "bios/ROM2.BIN" 	  } ] },
}

class BiosStatus:
    MISSING = "MISSING"
    INVALID = "INVALID"

def md5sum(filename, blocksize=65536):
    hash = md5()
    with open(filename, "rb") as f:
        for block in iter(lambda: f.read(blocksize), b""):
            hash.update(block)
    return hash.hexdigest()

def checkBios(systems, prefix):
    missingBios = {}
    for system in systems.keys():
        for file in systems[system]["biosFiles"]:
            filepath = prefix + "/" + file["file"]
            if isfile(filepath):
                md5 = md5sum(filepath)
                if md5 != file["md5"] and file["md5"] != "":
                    if system not in missingBios:
                        missingBios[system] = {}
                    missingBios[system][file["file"]] = { "status": BiosStatus.INVALID, "md5": file["md5"], "file": file["file"] }
            else:
                if system not in missingBios:
                    missingBios[system] = {}
                missingBios[system][file["file"]] = { "status": BiosStatus.MISSING, "md5": file["md5"], "file": file["file"] }
    return missingBios

def displayMissingBios(systems, missingBios):
    sortedMissingBios = OrderedDict(sorted(missingBios.items()))
    if sortedMissingBios:
        for system in sortedMissingBios:
            print "> {}".format(systems[system]["name"])
            for file in sortedMissingBios[system].keys():
                md5str = "-"
                if sortedMissingBios[system][file]["md5"] != "":
                    md5str = sortedMissingBios[system][file]["md5"]
                print "{} {} {}".format(sortedMissingBios[system][file]["status"], md5str, sortedMissingBios[system][file]["file"])
    else:
        print "No missing bios"

def createReadme(systems):
    for system in sorted(systems):
        print "{}:".format(systems[system]["name"])
        for bios in systems[system]["biosFiles"]:
            print "{} {}".format(bios["md5"], bios["file"])
        print ""

if __name__ == '__main__':
    if len(sys.argv) == 1:
        prefix = "/userdata"
        displayMissingBios(systems, checkBios(systems, prefix))
    elif sys.argv[1] == "--createReadme":
        createReadme(systems)

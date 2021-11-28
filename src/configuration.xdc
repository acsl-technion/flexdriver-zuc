###############################
## CONFIGURATION CONSTRAINTS ##
###############################

  # voltage
  set_property     CONFIG_VOLTAGE                     1.8       [current_design]
  set_property     CFGBVS                             GND       [current_design]

  # configuration mode
  set_property     CONFIG_MODE                        SPIx8     [current_design]

  # bitstream parameters

# when uncommenting div-1 - comment two lines below
 #set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN      DIV-1     [current_design]
  set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN      DISABLE   [current_design]
  set_property BITSTREAM.CONFIG.CONFIGRATE            127.5     [current_design]

  set_property BITSTREAM.GENERAL.COMPRESS             TRUE      [current_design]
  set_property BITSTREAM.CONFIG.UNUSEDPIN             PULLUP    [current_design]
  set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR        YES       [current_design]
  set_property BITSTREAM.CONFIG.SPI_FALL_EDGE         YES       [current_design]
  set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN      ENABLE    [current_design]
  set_property BITSTREAM.CONFIG.SPI_BUSWIDTH          8         [current_design]
  set_property BITSTREAM.CONFIG.CONFIGFALLBACK        DISABLE   [current_design]
  set_property BITSTREAM.CONFIG.NEXT_CONFIG_REBOOT    DISABLE   [current_design]

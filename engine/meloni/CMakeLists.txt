# Meloni engine, platform independent. Built as an ESP-IDF component by the open-086 firmware
# (its build_retro_go.sh copies engine/ into the retro-go app), and by ../../runner for the desktop.
# On the device lodepng comes from the retro-go component.
idf_component_register(SRCS "engine.c" "gfx.c" "audio.c" "prelude.c" "font8x8.c" "font8x16.c" "font12x24.c"
                       INCLUDE_DIRS "."
                       REQUIRES lua retro-go)
target_compile_options(${COMPONENT_LIB} PRIVATE -O2)

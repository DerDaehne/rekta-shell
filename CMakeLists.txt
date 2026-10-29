cmake_minimum_required(VERSION 3.25)
project(rekta-shell VERSION 0.1.0 LANGUAGES CXX)

# KDEInstallDirs picks its Qt version from the Qt that is already found.
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(ECM 6.0 REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)

# Programs of other packages, at the places a distribution puts them; a build with its own store paths overrides them.
set(QUICKSHELL quickshell CACHE STRING "Quickshell, as the starter runs it")
set(KWIN_WAYLAND_WRAPPER ${KDE_INSTALL_FULL_BINDIR}/kwin_wayland_wrapper CACHE FILEPATH "KWin's start command")
set(STARTPLASMA_WAYLAND ${KDE_INSTALL_FULL_BINDIR}/startplasma-wayland CACHE FILEPATH "Plasma's session start")
set(PLASMA_DBUS_RUN_SESSION_IF_NEEDED ${KDE_INSTALL_FULL_LIBEXECDIR}/plasma-dbus-run-session-if-needed
    CACHE FILEPATH "Plasma's session bus starter")
set(REKTA_DEFAULTS_FILE "" CACHE FILEPATH "Defaults for the shell's settings; empty leaves REKTA_DEFAULTS unset")

# The placeholders of session/ and of the two starters, named after what they stand for.
set(REKTA_BIN_DIR ${KDE_INSTALL_FULL_BINDIR})
set(REKTA_LIBEXEC_DIR ${KDE_INSTALL_FULL_LIBEXECDIR})
set(REKTA_SHELL_DIR ${KDE_INSTALL_FULL_DATADIR}/rekta-shell)
set(REKTA_SETTINGS_DIR ${KDE_INSTALL_FULL_DATADIR}/rekta-settings)
set(REKTA_KWIN_DATA_DIR ${KDE_INSTALL_FULL_DATADIR}/rekta-kwin)
set(REKTA_KWIN_PLUGIN_DIR ${KDE_INSTALL_FULL_LIBDIR}/rekta-kwin/plugins)
# Starts with a newline and ends a line in the starters, so an unset file leaves no blank line.
set(REKTA_DEFAULTS_EXPORT "")
if(REKTA_DEFAULTS_FILE)
    set(REKTA_DEFAULTS_EXPORT "\nexport REKTA_DEFAULTS=\"${REKTA_DEFAULTS_FILE}\"")
endif()

add_subdirectory(plugins/dbus)
add_subdirectory(kwin/fadeback)

set(generated ${CMAKE_CURRENT_BINARY_DIR}/generated)
configure_file(session/rekta.desktop ${generated}/rekta.desktop @ONLY)
configure_file(session/rekta-session ${generated}/rekta-session @ONLY)
configure_file(session/rekta-kwin ${generated}/rekta-kwin @ONLY)
configure_file(session/rekta-shell.in ${generated}/rekta-shell @ONLY)
configure_file(settings/rekta-settings.in ${generated}/rekta-settings @ONLY)
configure_file(session/systemd/rekta-shell.service ${generated}/rekta-shell.service @ONLY)
configure_file(session/systemd/plasma-kwin_wayland.service.d/rekta-session.conf
    ${generated}/kwin-rekta-session.conf @ONLY)

# KWin's parts live under rekta-kwin, where only the rekta session looks; nothing goes into share/kwin, etc/xdg or the
# plugin directory of Qt, which every session reads.
install(DIRECTORY shell/ DESTINATION ${KDE_INSTALL_DATADIR}/rekta-shell)
install(DIRECTORY kwin/effects DESTINATION ${KDE_INSTALL_DATADIR}/rekta-kwin/kwin)
install(FILES kwin/kwinrc DESTINATION ${KDE_INSTALL_DATADIR}/rekta-kwin/kwin)

install(PROGRAMS ${generated}/rekta-shell ${generated}/rekta-settings DESTINATION ${KDE_INSTALL_BINDIR})
install(FILES settings/shell.qml DESTINATION ${KDE_INSTALL_DATADIR}/rekta-settings)
install(FILES settings/rekta-settings.desktop DESTINATION ${KDE_INSTALL_APPDIR})

install(FILES ${generated}/rekta.desktop DESTINATION ${KDE_INSTALL_DATADIR}/wayland-sessions)
install(PROGRAMS ${generated}/rekta-session ${generated}/rekta-kwin DESTINATION ${KDE_INSTALL_LIBEXECDIR})
install(FILES ${generated}/rekta-shell.service DESTINATION ${KDE_INSTALL_SYSTEMDUSERUNITDIR})
install(FILES ${generated}/kwin-rekta-session.conf
    DESTINATION ${KDE_INSTALL_SYSTEMDUSERUNITDIR}/plasma-kwin_wayland.service.d RENAME rekta-session.conf)
install(FILES session/systemd/plasma-plasmashell.service.d/rekta-session.conf
    DESTINATION ${KDE_INSTALL_SYSTEMDUSERUNITDIR}/plasma-plasmashell.service.d)
install(FILES session/systemd/plasma-workspace.target.d/rekta-shell.conf
    DESTINATION ${KDE_INSTALL_SYSTEMDUSERUNITDIR}/plasma-workspace.target.d)

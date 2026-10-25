cmake_minimum_required(VERSION 3.25)
project(rekta-fadeback LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_AUTOMOC ON)
# The factory macro declares the plugin's Q_OBJECT class.
list(APPEND CMAKE_AUTOMOC_MACRO_NAMES KWIN_EFFECT_FACTORY)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)

# KWin links these without looking for them itself.
find_package(Qt6 REQUIRED COMPONENTS DBus Qml Widgets)
find_package(KWin REQUIRED)

# KWin knows a plugin by its file name.
add_library(rekta-fadeback MODULE fadeback.cpp)
set_target_properties(rekta-fadeback PROPERTIES PREFIX "")
target_compile_definitions(rekta-fadeback PRIVATE KPLUGINFACTORY_PLUGIN_CLASS_INTERNAL_NAME=rekta_fadeback_factory)
target_link_libraries(rekta-fadeback PRIVATE KWin::kwin Qt6::Qml)
install(TARGETS rekta-fadeback DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)

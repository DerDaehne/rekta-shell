cmake_minimum_required(VERSION 3.25)
project(rekta-shell-dbus LANGUAGES CXX)

find_package(ECM 6.0 REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS DBus Qml)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_qml_module(rektashelldbus
    URI RektaShell.DBus
    PLUGIN_TARGET rektashelldbus
    SOURCES dbusconnection.cpp dbusconnection.h marshalling.cpp marshalling.h
)
target_link_libraries(rektashelldbus PRIVATE Qt6::DBus)

set(module_dir ${KDE_INSTALL_QMLDIR}/RektaShell/DBus)
qt_query_qml_module(rektashelldbus QMLDIR qmldir TYPEINFO typeinfo)
install(TARGETS rektashelldbus LIBRARY DESTINATION ${module_dir})
install(FILES ${qmldir} ${typeinfo} DESTINATION ${module_dir})

cmake_minimum_required(VERSION 3.25)
project(rekta-shell-dbus-counterpart LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS DBus Qml)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_qml_module(dbuscounterpart
    URI DBusCounterpart
    PLUGIN_TARGET dbuscounterpart
    SOURCES counterpart.cpp counterpart.h
)
target_link_libraries(dbuscounterpart PRIVATE Qt6::DBus)

set(module_dir ${CMAKE_INSTALL_LIBDIR}/qt-6/qml/DBusCounterpart)
qt_query_qml_module(dbuscounterpart QMLDIR qmldir TYPEINFO typeinfo)
install(TARGETS dbuscounterpart LIBRARY DESTINATION ${module_dir})
install(FILES ${qmldir} ${typeinfo} DESTINATION ${module_dir})

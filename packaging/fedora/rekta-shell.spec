Name:           rekta-shell
Version:        0.1.0
Release:        1%{?dist}
Summary:        Desktop shell for KDE Plasma 6 that follows Rekta Design

License:        MIT AND CC-BY-4.0
URL:            https://github.com/DerDaehne/rekta-shell
Source0:        https://github.com/DerDaehne/rekta-shell/archive/v%{version}/rekta-shell-%{version}.tar.gz

ExclusiveArch:  x86_64

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  kf6-rpm-macros
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Widgets)
BuildRequires:  cmake(KWin)
BuildRequires:  pkgconfig(epoxy)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  qt6-qtbase-private-devel
# Plasma's own unit, which %%check compares the session's drop-in with
BuildRequires:  kwin
BuildRequires:  desktop-file-utils
# The QML tests
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  dbus-daemon
BuildRequires:  atkinson-hyperlegible-next-fonts

# Quickshell 0.3 comes from the COPR errornointernet/quickshell until Fedora has it
Requires:       (quickshell >= 0.3 with quickshell < 0.4)
# rekta-fadeback uses KWin's internal headers, which change with every Plasma minor release
Requires:       (kwin-libs%{?_isa} >= 6.8 with kwin-libs%{?_isa} < 6.9)
Requires:       kwin
Requires:       plasma-workspace >= 6.8
Requires:       kpipewire
Requires:       libkscreen
Requires:       libcanberra-gtk3
Requires:       kf6-kirigami
Requires:       kf6-qqc2-desktop-style
Requires:       atkinson-hyperlegible-next-fonts
Requires:       qt6-qtdeclarative

%description
rekta-shell is a desktop shell for KDE Plasma 6 on Wayland, built with
Quickshell on KWin, that follows Rekta Design. It runs as the session "rekta"
next to the regular Plasma session: Plasma's services without plasmashell, with
the shell in its place. KWin's effects for the shell are loaded only in that
session.

%prep
%autosetup

%build
%cmake_kf6 -DREKTA_DEFAULTS_FILE=%{_sysconfdir}/rekta-shell/defaults.json
%cmake_build

%install
%cmake_install
install -d %{buildroot}%{_sysconfdir}/rekta-shell
printf '{ "background": "rekta" }\n' > %{buildroot}%{_sysconfdir}/rekta-shell/defaults.json

%check
# The session's KWin command is Plasma's, behind the wrapper that adds the rekta paths.
plasma=$(sed -n 's/^ExecStart=//p' %{_userunitdir}/plasma-kwin_wayland.service)
rekta=$(sed -n 's|^ExecStart=%{_libexecdir}/rekta-kwin ||p' \
    %{buildroot}%{_userunitdir}/plasma-kwin_wayland.service.d/rekta-session.conf)
test -n "$plasma"
if [ "$rekta" != "$plasma" ]; then
    echo "the rekta drop-in runs '$rekta' through rekta-kwin, plasma-kwin_wayland.service runs '$plasma'" >&2
    exit 1
fi

# Plasma reads these in every session: the package may put nothing there.
for path in %{_datadir}/kwin %{_qt6_plugindir}/kwin %{_sysconfdir}/xdg; do
    if [ -e %{buildroot}$path ]; then
        echo "the package puts $path into every session" >&2
        exit 1
    fi
done

# The validator does not know DesktopNames, a key of session entries.
session_errors=$(desktop-file-validate %{buildroot}%{_datadir}/wayland-sessions/rekta.desktop 2>&1 | grep -v 'key "DesktopNames"' || true)
if [ -n "$session_errors" ]; then
    echo "$session_errors" >&2
    exit 1
fi
desktop-file-validate %{buildroot}%{_datadir}/applications/rekta-settings.desktop

# The tests of the flake check, against this system's Qt.
src=$PWD
mkdir -p qml-tests/home
cmake -S tests/counterpart -B qml-tests/counterpart -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$src/qml-tests/counterpart-root -DCMAKE_INSTALL_LIBDIR=lib
cmake --build qml-tests/counterpart
cmake --install qml-tests/counterpart
cd qml-tests
export HOME=$PWD/home LANG=C.UTF-8 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
# Only the typeface, as the flake check has it: the system's other fonts and rules change the text metrics the tests measure.
cat > fonts.conf <<FONTS
<?xml version="1.0"?>
<fontconfig><dir>%{_datadir}/fonts/atkinson-hyperlegible-next-fonts</dir><cachedir>$PWD/fontcache</cachedir></fontconfig>
FONTS
export FONTCONFIG_FILE=$PWD/fonts.conf
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent/system_bus_socket
export QML_IMPORT_PATH=%{buildroot}%{_qt6_qmldir}:$src/qml-tests/counterpart-root/lib/qt-6/qml
QMLTESTRUNNER=%{_qt6_bindir}/qmltestrunner $src/tests/run-qml-tests.sh $src

%files
%license LICENSE LICENSE-docs NOTICE
%doc README.md
%{_bindir}/rekta-shell
%{_bindir}/rekta-settings
%{_libexecdir}/rekta-session
%{_libexecdir}/rekta-kwin
%{_datadir}/rekta-shell/
%{_datadir}/rekta-settings/
%{_datadir}/rekta-kwin/
%{_libdir}/rekta-kwin/
%{_qt6_qmldir}/RektaShell/
%{_datadir}/wayland-sessions/rekta.desktop
%{_datadir}/applications/rekta-settings.desktop
%{_userunitdir}/rekta-shell.service
%dir %{_userunitdir}/plasma-kwin_wayland.service.d
%{_userunitdir}/plasma-kwin_wayland.service.d/rekta-session.conf
%dir %{_userunitdir}/plasma-plasmashell.service.d
%{_userunitdir}/plasma-plasmashell.service.d/rekta-session.conf
%dir %{_userunitdir}/plasma-workspace.target.d
%{_userunitdir}/plasma-workspace.target.d/rekta-shell.conf
%dir %{_sysconfdir}/rekta-shell
%config(noreplace) %{_sysconfdir}/rekta-shell/defaults.json

%changelog
* Thu Oct 29 2026 rekta-shell maintainers - 0.1.0-1
- First package

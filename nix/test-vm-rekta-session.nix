# A prototype of the rekta session, for the test VM only: Plasma's services without plasmashell, a Quickshell
# surface in its place. The Plasma session stays as it is.
{ lib, pkgs, ... }:

let
  plasma-workspace = pkgs.kdePackages.plasma-workspace;

  startSession = pkgs.writeShellScript "start-rekta-session" ''
    export XDG_SESSION_DESKTOP=rekta
    export PLASMA_DEFAULT_SHELL=org.kde.plasma.desktop
    exec ${plasma-workspace}/libexec/plasma-dbus-run-session-if-needed ${plasma-workspace}/bin/startplasma-wayland
  '';

  session = pkgs.runCommand "rekta-session" { passthru.providedSessions = [ "rekta" ]; } ''
    mkdir -p $out/share/wayland-sessions $out/lib/systemd/user/plasma-plasmashell.service.d
    cat > $out/share/wayland-sessions/rekta.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=rekta
    Comment=Plasma's services with Quickshell instead of plasmashell
    Exec=${startSession}
    TryExec=${startSession}
    DesktopNames=KDE
    EOF
    cat > $out/lib/systemd/user/plasma-plasmashell.service.d/rekta-session.conf <<EOF
    [Unit]
    ConditionEnvironment=!XDG_SESSION_DESKTOP=rekta
    EOF
  '';

  testSurface = pkgs.runCommand "rekta-session-test-surface" { } ''
    mkdir $out
    cp -r ${../shell/Rekta} $out/Rekta
    cp ${pkgs.writeText "shell.qml" ''
      import QtQuick
      import Quickshell
      import Quickshell.Io
      import Rekta

      ShellRoot {
          PanelWindow {
              anchors {
                  top: true
                  left: true
                  right: true
              }
              implicitHeight: Tokens.controlHeight * 2
              color: Tokens.color.surface

              // Without plasmashell nobody reports KSplash's last stage, and the splash stays until its timeout.
              Component.onCompleted: splashDone.running = true

              Title {
                  anchors.centerIn: parent
                  text: "rekta session: Quickshell test surface, no plasmashell"
              }
          }

          Process {
              id: splashDone
              command: [ "${pkgs.systemd}/bin/busctl", "--user", "call", "org.kde.KSplash", "/KSplash", "org.kde.KSplash", "setStage", "s", "desktop" ]
          }
      }
    ''} $out/shell.qml
  '';
in
{
  services.displayManager.sessionPackages = [ session ];
  systemd.packages = [ session ];

  systemd.user.services.rekta-test-surface = {
    description = "Quickshell test surface of the rekta session";
    wantedBy = [ "plasma-workspace.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "plasma-ksmserver.service" ];
    unitConfig.ConditionEnvironment = "XDG_SESSION_DESKTOP=rekta";
    environment.QML_IMPORT_PATH = "${testSurface}";
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.quickshell} --path ${testSurface}";
      Restart = "on-failure";
      Slice = "session.slice";
    };
  };
}

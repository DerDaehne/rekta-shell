#pragma once

#include <QDBusConnection>
#include <QDBusVirtualObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// The other end of the bus for the tests of RektaShell.DBus, written against QtDBus alone. It owns
// org.rekta.Counterpart, echoes every call to /echo back (or fails when asked "Fail") and records what arrived; it
// sends signals, calls methods and asks the bus who owns a name.
class Counterpart : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // The signature of the last call to /echo, read from the message on the wire.
    Q_PROPERTY(QString lastSignature READ lastSignature NOTIFY echoed FINAL)
    // The Qt types of the values in the last call's a{sv} arguments, by key.
    Q_PROPERTY(QVariantMap variantTypes READ variantTypes NOTIFY echoed FINAL)

public:
    explicit Counterpart(QObject *parent = nullptr);
    ~Counterpart() override;

    Q_INVOKABLE void emitSignal(const QString &path, const QString &interfaceName, const QString &member, const QVariantList &args);
    // Replies with replied(); an error reply carries its message as the only value.
    Q_INVOKABLE void call(const QString &service,
                          const QString &path,
                          const QString &interfaceName,
                          const QString &member,
                          const QVariantList &args);
    // The unique name owning name, or "" when nobody does.
    Q_INVOKABLE QString nameOwner(const QString &name);

    QString lastSignature() const
    {
        return m_lastSignature;
    }
    QVariantMap variantTypes() const
    {
        return m_variantTypes;
    }

    void record(const QDBusMessage &message);

Q_SIGNALS:
    void echoed();
    void replied(const QString &signature, const QVariantList &values, const QString &error);

private:
    QDBusConnection m_connection;
    QString m_lastSignature;
    QVariantMap m_variantTypes;
};

// A stand-in for powerdevil's org.kde.ScreenBrightness, written against QtDBus alone: while running it owns the name,
// answers property reads on /org/kde/ScreenBrightness and below, records SetBrightness and sends the signals.
class FakeScreenBrightness : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Drops the name when false, as when powerdevil is not running; takes it again when true.
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged FINAL)

public:
    explicit FakeScreenBrightness(QObject *parent = nullptr);
    ~FakeScreenBrightness() override;

    Q_INVOKABLE void addDisplay(const QString &name, const QString &label, int brightness, int max, bool announce = true);
    Q_INVOKABLE void removeDisplay(const QString &name, bool announce = true);
    // A change from elsewhere (a key, another program): the new brightness is read afterwards and the signal sent.
    Q_INVOKABLE void changeBrightness(const QString &name, int brightness, const QString &context = {});
    Q_INVOKABLE void changeRange(const QString &name, int max, int brightness);

    bool running() const
    {
        return m_running;
    }
    void setRunning(bool running);

    // What SetBrightness got, as {name, brightness, flags}.
    void recordSet(const QString &name, int brightness, uint flags);
    // The Display interface's properties of a display, empty when there is none of that name.
    QVariantMap properties(const QString &name) const;
    QStringList names() const;

Q_SIGNALS:
    void runningChanged();
    void setBrightnessCalled(const QString &name, int brightness, uint flags);

private:
    struct Display {
        QString name;
        QString label;
        int brightness;
        int max;
    };
    void announceSignal(const QString &member, const QVariantList &args);

    QDBusConnection m_connection;
    QList<Display> m_displays;
    bool m_running = false;
};

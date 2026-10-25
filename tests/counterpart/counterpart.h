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

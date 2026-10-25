#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QJSValue>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <optional>

// A connection of its own to the session or system bus: listen to signals, call methods, own names. Each instance has
// its own connection, so an instance that goes away (a reload of the shell) takes its names and subscriptions with it
// and leaves the next owner in line the name.
class DBusConnection : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Read on first use; changing it later has no effect.
    Q_PROPERTY(Bus bus MEMBER m_bus FINAL)
    // Answers calls to the owned objects: (path, interface, member, args) => the reply's values. With several out
    // arguments it returns an array of them; a thrown Error becomes an error reply.
    Q_PROPERTY(QJSValue handler READ handler WRITE setHandler FINAL)

public:
    enum Bus { Session, System };
    Q_ENUM(Bus)

    explicit DBusConnection(QObject *parent = nullptr);
    ~DBusConnection() override;

    QJSValue handler() const
    {
        return m_handler;
    }
    void setHandler(const QJSValue &handler)
    {
        m_handler = handler;
    }

    // An empty service or path listens to every sender or path.
    Q_INVOKABLE bool listen(const QString &interfaceName,
                            const QString &member,
                            const QString &service = {},
                            const QString &path = {});
    // Calls back (error, values): error is null on success, else the D-Bus error name and message.
    Q_INVOKABLE void call(const QString &service,
                          const QString &path,
                          const QString &interfaceName,
                          const QString &method,
                          const QJSValue &args,
                          const QString &signature,
                          const QJSValue &callback = {});
    // Exports the interfaces of introspectionXml (its <interface> elements) at path and every path below it, and queues
    // for the name.
    Q_INVOKABLE bool own(const QString &name, const QString &path, const QString &introspectionXml);

    // The reply to a call to an owned object: the handler's values, typed by the method's out arguments.
    QDBusMessage answer(const QDBusMessage &call, const QString &outSignature);

Q_SIGNALS:
    void received(const QString &sender,
                  const QString &path,
                  const QString &interfaceName,
                  const QString &member,
                  const QVariantList &args);

private Q_SLOTS:
    void deliver(const QDBusMessage &message);

private:
    QDBusConnection connection();
    void respond(const QJSValue &callback, const QString &error, const QVariantList &values);

    Bus m_bus = Session;
    QJSValue m_handler;
    const QString m_name;
    std::optional<QDBusConnection> m_connection;
};

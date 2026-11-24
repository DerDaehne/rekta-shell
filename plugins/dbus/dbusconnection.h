#pragma once

#include "marshalling.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QJSValue>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <optional>
#include <functional>

// The handle a handler is given to answer a call later, once: send(error, value).
class Responder : public QObject
{
    Q_OBJECT

public:
    using Answer = std::function<void(const Marshalling::Encoded &)>;

    Responder(Answer answer, QString signature, QObject *parent);

    // error is null or empty for success, else its text; value is what the handler would have returned. Send exactly once:
    // after the answer the responder is freed, and a later send throws a TypeError (a second send in the same turn of the
    // event loop does nothing).
    Q_INVOKABLE void send(const QJSValue &error, const QJSValue &value);

private:
    Answer m_answer;
    QString m_signature;
};

// A connection of its own to the session or system bus: listen to signals, call methods, own names, send signals. Each
// instance has its own connection, so an instance that goes away (a reload of the shell) takes its names and
// subscriptions with it and leaves the next owner in line the name.
class DBusConnection : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Read on first use; changing it later has no effect.
    Q_PROPERTY(Bus bus MEMBER m_bus FINAL)
    // Answers calls to the owned objects: (path, interface, member, args) => the reply's values. With several out
    // arguments it returns an array of them; a thrown Error becomes an error reply. A property read asks it as a method
    // of the property's name without arguments. A method call also gets a fifth argument, a Responder: a handler that
    // returns it answers when it calls its send(error, value), at any later time, and the call stays open until then.
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
    // Calls back (error, values): error is null on success, else the D-Bus error name and message. A call that gets no
    // reply within timeoutMs milliseconds (default: the bus library's 25 s) calls back with NoReply.
    Q_INVOKABLE void call(const QString &service,
                          const QString &path,
                          const QString &interfaceName,
                          const QString &method,
                          const QJSValue &args,
                          const QString &signature,
                          const QJSValue &callback = {},
                          int timeoutMs = -1);
    // Exports the interfaces of introspectionXml (its <interface> elements) at path and every path below it, and queues
    // for the name. Their properties can only be read.
    Q_INVOKABLE bool own(const QString &name, const QString &path, const QString &introspectionXml);
    // Sends a signal from path, its arguments typed by signature as a call's are; false when they do not fit the
    // signature or there is no bus.
    Q_INVOKABLE bool emitSignal(const QString &path,
                                const QString &interfaceName,
                                const QString &member,
                                const QJSValue &args,
                                const QString &signature);

    // The handler's answer to a call to an owned object, typed by signature, or the error text.
    Marshalling::Encoded ask(const QString &path,
                             const QString &interfaceName,
                             const QString &member,
                             const QVariantList &args,
                             const QString &signature,
                             const Responder::Answer &later = {});

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
    void respondLater(const QJSValue &callback, const QString &error);
    void respond(const QJSValue &callback, const QString &error, const QVariantList &values);

    struct Subscription {
        QString service;
        QString path;
        QString interfaceName;
        QString member;
    };

    Bus m_bus = Session;
    QJSValue m_handler;
    const QString m_name;
    std::optional<QDBusConnection> m_connection;
    QList<Subscription> m_subscriptions;
    QStringList m_exportedPaths;
};

#include "dbusconnection.h"

#include "marshalling.h"

#include <QDBusConnectionInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDBusVirtualObject>
#include <QJSEngine>
#include <QTimer>
#include <QUuid>
#include <QXmlStreamReader>

#include <algorithm>

using namespace Qt::StringLiterals;

namespace
{

struct Method {
    QString in;
    QString out;
};

// Methods by interface name, then by method name.
using Interfaces = QHash<QString, QHash<QString, Method>>;

// Collects each method's argument types from the elements of introspection XML, in document order.
class InterfaceReader
{
public:
    Interfaces interfaces;

    void read(QStringView element, const QXmlStreamAttributes &attributes)
    {
        if (element == u"annotation")
            return;
        if (element == u"arg") {
            addArgument(attributes);
            return;
        }
        m_method = element == u"method" ? attributes.value(u"name").toString() : QString();
        if (element == u"interface")
            m_interface = attributes.value(u"name").toString();
        if (!m_method.isEmpty())
            interfaces[m_interface].insert(m_method, {});
    }

private:
    void addArgument(const QXmlStreamAttributes &attributes)
    {
        if (m_method.isEmpty())
            return;
        Method &method = interfaces[m_interface][m_method];
        QString &types = attributes.value(u"direction") == u"out" ? method.out : method.in;
        types += attributes.value(u"type");
    }

    QString m_interface;
    QString m_method;
};

bool hasValidSignatures(const QHash<QString, Method> &methods)
{
    return std::all_of(methods.cbegin(), methods.cend(), [](const Method &method) {
        return Marshalling::completeTypes(method.in) && Marshalling::completeTypes(method.out);
    });
}

std::optional<Interfaces> readInterfaces(const QString &xml)
{
    // The interfaces stand side by side, which XML only accepts inside one element.
    QXmlStreamReader xmlReader(u"<node>"_s + xml + u"</node>"_s);
    InterfaceReader reader;
    while (!xmlReader.atEnd()) {
        if (xmlReader.readNext() == QXmlStreamReader::StartElement)
            reader.read(xmlReader.name(), xmlReader.attributes());
    }
    const Interfaces &interfaces = reader.interfaces;
    if (xmlReader.hasError() || !std::all_of(interfaces.cbegin(), interfaces.cend(), hasValidSignatures))
        return std::nullopt;
    return interfaces;
}

// An object own() exports. It answers the methods of its interfaces through the connection's handler and leaves
// introspection, properties and calls without an interface to QtDBus.
class ExportedObject : public QDBusVirtualObject
{
public:
    ExportedObject(DBusConnection *owner, Interfaces interfaces, QString xml)
        : QDBusVirtualObject(owner)
        , m_owner(owner)
        , m_interfaces(std::move(interfaces))
        , m_xml(std::move(xml))
    {
    }

    QString introspect(const QString &) const override
    {
        return m_xml;
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.interface().isEmpty() || message.interface().startsWith(u"org.freedesktop.DBus."))
            return false;
        connection.send(reply(message));
        return true;
    }

private:
    QDBusMessage reply(const QDBusMessage &message) const
    {
        const auto interface = m_interfaces.constFind(message.interface());
        if (interface == m_interfaces.cend())
            return message.createErrorReply(QDBusError::UnknownInterface,
                                            u"%1 has no interface %2"_s.arg(message.path(), message.interface()));
        const auto method = interface->constFind(message.member());
        if (method == interface->cend())
            return message.createErrorReply(QDBusError::UnknownMethod,
                                            u"%1 has no method %2"_s.arg(message.interface(), message.member()));
        if (message.signature() != method->in)
            return message.createErrorReply(QDBusError::InvalidArgs,
                                            u"%1 takes (%2), not (%3)"_s.arg(message.member(), method->in, message.signature()));
        return m_owner->answer(message, method->out);
    }

    DBusConnection *m_owner;
    Interfaces m_interfaces;
    QString m_xml;
};

// A D-Bus error as the callback of call() reports it.
QString errorText(const QDBusError &error)
{
    return error.name() + u": "_s + error.message();
}

// One out argument is the handler's value itself, several are the array it returns.
QVariantList replyValues(const QJSValue &result, const QString &outSignature)
{
    const qsizetype count = Marshalling::completeTypes(outSignature).value_or(QStringList()).size();
    const QVariant value = result.toVariant(QJSValue::ConvertJSObjects);
    if (count == 0)
        return {};
    if (count == 1)
        return {value};
    return value.toList();
}

}

DBusConnection::DBusConnection(QObject *parent)
    : QObject(parent)
    , m_name(u"rekta-shell-dbus-"_s + QUuid::createUuid().toString(QUuid::WithoutBraces))
{
}

DBusConnection::~DBusConnection()
{
    if (!m_connection)
        return;
    // The connection closes, and the bus hands its names on, once its last reference is gone.
    m_connection.reset();
    QDBusConnection::disconnectFromBus(m_name);
}

QDBusConnection DBusConnection::connection()
{
    if (!m_connection)
        m_connection = QDBusConnection::connectToBus(m_bus == System ? QDBusConnection::SystemBus : QDBusConnection::SessionBus,
                                                     m_name);
    return *m_connection;
}

bool DBusConnection::listen(const QString &interfaceName, const QString &member, const QString &service, const QString &path)
{
    return connection().connect(service, path, interfaceName, member, this, SLOT(deliver(QDBusMessage)));
}

void DBusConnection::deliver(const QDBusMessage &message)
{
    Q_EMIT received(message.service(), message.path(), message.interface(), message.member(), Marshalling::decode(message.arguments()));
}

void DBusConnection::call(const QString &service,
                          const QString &path,
                          const QString &interfaceName,
                          const QString &method,
                          const QJSValue &args,
                          const QString &signature,
                          const QJSValue &callback)
{
    const Marshalling::Encoded encoded = Marshalling::encode(args.toVariant(QJSValue::ConvertJSObjects).toList(), signature);
    if (!encoded.error.isEmpty()) {
        respondLater(callback, encoded.error);
        return;
    }
    const QDBusConnection bus = connection();
    if (!bus.isConnected()) {
        respondLater(callback, errorText(QDBusError(QDBusError::Disconnected, bus.lastError().message())));
        return;
    }
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interfaceName, method);
    message.setArguments(encoded.arguments);
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, callback](QDBusPendingCallWatcher *finished) {
        finished->deleteLater();
        const QDBusMessage reply = finished->reply();
        if (reply.type() == QDBusMessage::ErrorMessage)
            respond(callback, errorText(QDBusError(reply)), {});
        else
            respond(callback, {}, Marshalling::decode(reply.arguments()));
    });
}

void DBusConnection::respondLater(const QJSValue &callback, const QString &error)
{
    // Like every answer, this one arrives after call() has returned.
    QTimer::singleShot(0, this, [this, callback, error] {
        respond(callback, error, {});
    });
}

void DBusConnection::respond(const QJSValue &callback, const QString &error, const QVariantList &values)
{
    QJSEngine *engine = qjsEngine(this);
    if (!engine || !callback.isCallable())
        return;
    const QJSValue errorValue = error.isEmpty() ? QJSValue(QJSValue::NullValue) : QJSValue(error);
    const QJSValue result = callback.call({errorValue, engine->toScriptValue(values)});
    if (result.isError())
        qWarning().noquote() << "DBusConnection: the callback threw" << result.toString();
}

bool DBusConnection::own(const QString &name, const QString &path, const QString &introspectionXml)
{
    std::optional<Interfaces> interfaces = readInterfaces(introspectionXml);
    if (!interfaces) {
        qWarning() << "DBusConnection: the introspection XML for" << path << "is not XML or has a type that is not a valid D-Bus signature";
        return false;
    }
    if (!connection().isConnected()) {
        qWarning() << "DBusConnection: no bus to own" << name << "on:" << connection().lastError().message();
        return false;
    }
    auto *object = new ExportedObject(this, *std::move(interfaces), introspectionXml);
    if (!connection().registerVirtualObject(path, object, QDBusConnection::SubPath)) {
        qWarning() << "DBusConnection: cannot export" << path << "for" << name;
        delete object;
        return false;
    }
    // In line behind the current owner and replaceable by the next one, so a reload hands the name on without a gap.
    const QDBusReply<QDBusConnectionInterface::RegisterServiceReply> reply = connection().interface()->registerService(
        name, QDBusConnectionInterface::QueueService, QDBusConnectionInterface::AllowReplacement);
    if (!reply.isValid())
        qWarning() << "DBusConnection: cannot own" << name << reply.error().message();
    return reply.isValid();
}

QDBusMessage DBusConnection::answer(const QDBusMessage &call, const QString &outSignature)
{
    QJSEngine *engine = qjsEngine(this);
    if (!engine || !m_handler.isCallable())
        return call.createErrorReply(QDBusError::Failed, u"no handler answers %1"_s.arg(call.member()));
    const QJSValue result =
        m_handler.call({call.path(), call.interface(), call.member(), engine->toScriptValue(Marshalling::decode(call.arguments()))});
    if (result.isError())
        return call.createErrorReply(QDBusError::Failed, result.property(u"message"_s).toString());
    const Marshalling::Encoded encoded = Marshalling::encode(replyValues(result, outSignature), outSignature);
    if (!encoded.error.isEmpty())
        return call.createErrorReply(QDBusError::Failed, encoded.error);
    return call.createReply(encoded.arguments);
}

#include "counterpart.h"

#include <QDBusArgument>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QUuid>

using namespace Qt::StringLiterals;

namespace
{

class Echo : public QDBusVirtualObject
{
public:
    explicit Echo(Counterpart *counterpart)
        : QDBusVirtualObject(counterpart)
        , m_counterpart(counterpart)
    {
    }

    QString introspect(const QString &) const override
    {
        return {};
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        m_counterpart->record(message);
        if (message.member() == u"Fail")
            connection.send(message.createErrorReply(u"org.rekta.Counterpart.Failed"_s, u"asked to fail"_s));
        else
            connection.send(message.createReply(message.arguments()));
        return true;
    }

private:
    Counterpart *m_counterpart;
};

QVariantList plainValues(const QVariantList &arguments)
{
    QVariantList values;
    for (const QVariant &argument : arguments) {
        const bool isPath = argument.metaType() == QMetaType::fromType<QDBusObjectPath>();
        values.append(isPath ? QVariant(argument.value<QDBusObjectPath>().path()) : argument);
    }
    return values;
}

bool isDictionary(const QVariant &argument)
{
    return argument.metaType() == QMetaType::fromType<QDBusArgument>()
        && argument.value<QDBusArgument>().currentSignature() == u"a{sv}";
}

}

Counterpart::Counterpart(QObject *parent)
    : QObject(parent)
    , m_connection(QDBusConnection::connectToBus(QDBusConnection::SessionBus, QUuid::createUuid().toString()))
{
    m_connection.registerVirtualObject(u"/echo"_s, new Echo(this));
    // The counterpart of the test file that runs now takes the name from the one before.
    m_connection.interface()->registerService(u"org.rekta.Counterpart"_s,
                                              QDBusConnectionInterface::ReplaceExistingService,
                                              QDBusConnectionInterface::AllowReplacement);
}

Counterpart::~Counterpart()
{
    QDBusConnection::disconnectFromBus(m_connection.name());
}

void Counterpart::emitSignal(const QString &path, const QString &interfaceName, const QString &member, const QVariantList &args)
{
    QDBusMessage message = QDBusMessage::createSignal(path, interfaceName, member);
    message.setArguments(args);
    m_connection.send(message);
}

void Counterpart::call(const QString &service, const QString &path, const QString &interfaceName, const QString &member, const QVariantList &args)
{
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interfaceName, member);
    message.setArguments(args);
    auto *watcher = new QDBusPendingCallWatcher(m_connection.asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *finished) {
        finished->deleteLater();
        const QDBusMessage reply = finished->reply();
        Q_EMIT replied(reply.signature(), plainValues(reply.arguments()), reply.errorName());
    });
}

QString Counterpart::nameOwner(const QString &name)
{
    return m_connection.interface()->serviceOwner(name).value();
}

void Counterpart::record(const QDBusMessage &message)
{
    m_lastSignature = message.signature();
    m_variantTypes.clear();
    for (const QVariant &argument : message.arguments()) {
        if (!isDictionary(argument))
            continue;
        const QVariantMap dictionary = qdbus_cast<QVariantMap>(argument);
        for (const auto &[key, value] : dictionary.asKeyValueRange())
            m_variantTypes.insert(key, QString::fromLatin1(value.typeName()));
    }
    Q_EMIT echoed();
}

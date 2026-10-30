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

namespace
{

const auto rootPath = u"/org/kde/ScreenBrightness"_s;
const auto rootInterface = u"org.kde.ScreenBrightness"_s;
const auto displayInterface = u"org.kde.ScreenBrightness.Display"_s;

class ScreenBrightnessObject : public QDBusVirtualObject
{
public:
    explicit ScreenBrightnessObject(FakeScreenBrightness *fake)
        : QDBusVirtualObject(fake)
        , m_fake(fake)
    {
    }

    QString introspect(const QString &) const override
    {
        return {};
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        connection.send(reply(message));
        return true;
    }

private:
    QDBusMessage reply(const QDBusMessage &message) const
    {
        const QString name = message.path().mid(rootPath.size() + 1);
        if (message.member() == u"Get" && message.path() == rootPath)
            return message.createReply(QVariant::fromValue(QDBusVariant(m_fake->names())));
        if (message.member() == u"GetAll" && !m_fake->properties(name).isEmpty())
            return message.createReply(QVariant::fromValue(m_fake->properties(name)));
        if (message.member() == u"SetBrightness" && !m_fake->properties(name).isEmpty()) {
            m_fake->recordSet(name, message.arguments().at(0).toInt(), message.arguments().at(1).toUInt());
            return message.createReply();
        }
        return message.createErrorReply(QDBusError::UnknownObject, u"no such display or call: %1 %2"_s.arg(message.path(), message.member()));
    }

    FakeScreenBrightness *m_fake;
};

}

FakeScreenBrightness::FakeScreenBrightness(QObject *parent)
    : QObject(parent)
    , m_connection(QDBusConnection::connectToBus(QDBusConnection::SessionBus, QUuid::createUuid().toString()))
{
    m_connection.registerVirtualObject(rootPath, new ScreenBrightnessObject(this), QDBusConnection::SubPath);
    setRunning(true);
}

FakeScreenBrightness::~FakeScreenBrightness()
{
    QDBusConnection::disconnectFromBus(m_connection.name());
}

void FakeScreenBrightness::setRunning(bool running)
{
    if (running == m_running)
        return;
    m_running = running;
    if (running)
        m_connection.interface()->registerService(u"org.kde.ScreenBrightness"_s,
                                                  QDBusConnectionInterface::ReplaceExistingService,
                                                  QDBusConnectionInterface::AllowReplacement);
    else
        m_connection.interface()->unregisterService(u"org.kde.ScreenBrightness"_s);
    Q_EMIT runningChanged();
}

QStringList FakeScreenBrightness::names() const
{
    QStringList names;
    for (const Display &display : m_displays)
        names.append(display.name);
    return names;
}

QVariantMap FakeScreenBrightness::properties(const QString &name) const
{
    for (const Display &display : m_displays) {
        if (display.name == name)
            return {{u"Label"_s, display.label}, {u"IsInternal"_s, false}, {u"MaxBrightness"_s, display.max}, {u"Brightness"_s, display.brightness}};
    }
    return {};
}

void FakeScreenBrightness::recordSet(const QString &name, int brightness, uint flags)
{
    Q_EMIT setBrightnessCalled(name, brightness, flags);
}

void FakeScreenBrightness::announceSignal(const QString &member, const QVariantList &args)
{
    QDBusMessage message = QDBusMessage::createSignal(rootPath, rootInterface, member);
    message.setArguments(args);
    m_connection.send(message);
}

void FakeScreenBrightness::addDisplay(const QString &name, const QString &label, int brightness, int max, bool announce)
{
    m_displays.append({name, label, brightness, max});
    if (announce)
        announceSignal(u"DisplayAdded"_s, {name});
}

void FakeScreenBrightness::removeDisplay(const QString &name, bool announce)
{
    m_displays.removeIf([&name](const Display &display) {
        return display.name == name;
    });
    if (announce)
        announceSignal(u"DisplayRemoved"_s, {name});
}

void FakeScreenBrightness::changeBrightness(const QString &name, int brightness, const QString &context)
{
    for (Display &display : m_displays) {
        if (display.name == name)
            display.brightness = brightness;
    }
    announceSignal(u"BrightnessChanged"_s, {name, brightness, u":1.7"_s, context});
}

void FakeScreenBrightness::changeRange(const QString &name, int max, int brightness)
{
    for (Display &display : m_displays) {
        if (display.name == name) {
            display.max = max;
            display.brightness = brightness;
        }
    }
    announceSignal(u"BrightnessRangeChanged"_s, {name, max, brightness});
}

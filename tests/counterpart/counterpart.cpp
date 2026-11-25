#include "counterpart.h"

#include <QDBusArgument>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QUuid>

#include <optional>
#include <utility>

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

// Records every call and answers it with the same values, or leaves it without an answer.
class Answer : public QDBusVirtualObject
{
public:
    Answer(Counterpart *counterpart, std::optional<QVariantList> values, std::optional<QPair<QString, QString>> error = std::nullopt)
        : QDBusVirtualObject(counterpart)
        , m_counterpart(counterpart)
        , m_values(std::move(values))
        , m_error(std::move(error))
    {
    }

    QString introspect(const QString &) const override
    {
        return {};
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        m_counterpart->record(message);
        if (m_error)
            connection.send(message.createErrorReply(m_error->first, m_error->second));
        else if (m_values)
            connection.send(message.createReply(*m_values));
        return true;
    }

private:
    Counterpart *m_counterpart;
    std::optional<QVariantList> m_values;
    std::optional<QPair<QString, QString>> m_error;
};

QVariant plainValue(const QVariant &value);

QVariantList plainElements(const QDBusArgument &argument)
{
    QVariantList elements;
    while (!argument.atEnd())
        elements.append(plainValue(argument.asVariant()));
    return elements;
}

QVariantMap plainMap(const QDBusArgument &argument)
{
    QVariantMap map;
    argument.beginMap();
    while (!argument.atEnd()) {
        argument.beginMapEntry();
        const QString key = plainValue(argument.asVariant()).toString();
        map.insert(key, plainValue(argument.asVariant()));
        argument.endMapEntry();
    }
    argument.endMap();
    return map;
}

QVariant plainContainer(const QDBusArgument &argument)
{
    switch (argument.currentType()) {
    case QDBusArgument::MapType:
        return plainMap(argument);
    case QDBusArgument::ArrayType: {
        argument.beginArray();
        const QVariantList elements = plainElements(argument);
        argument.endArray();
        return elements;
    }
    case QDBusArgument::StructureType: {
        argument.beginStructure();
        const QVariantList members = plainElements(argument);
        argument.endStructure();
        return members;
    }
    default:
        return plainValue(argument.asVariant());
    }
}

// Lists, maps and plain values in place of D-Bus containers, variants unpacked, so QML can read what arrived.
QVariant plainValue(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<QDBusArgument>())
        return plainContainer(value.value<QDBusArgument>());
    if (value.metaType() == QMetaType::fromType<QDBusVariant>())
        return plainValue(value.value<QDBusVariant>().variant());
    if (value.metaType() == QMetaType::fromType<QDBusObjectPath>())
        return value.value<QDBusObjectPath>().path();
    return value;
}

QVariantList plainValues(const QVariantList &arguments)
{
    QVariantList values;
    for (const QVariant &argument : arguments)
        values.append(plainValue(argument));
    return values;
}

bool isDictionary(const QVariant &argument)
{
    return argument.metaType() == QMetaType::fromType<QDBusArgument>()
        && argument.value<QDBusArgument>().currentSignature() == u"a{sv}";
}

// The Qt types of the values in the a{sv} arguments, by key.
QVariantMap variantTypesOf(const QVariantList &arguments)
{
    QVariantMap types;
    for (const QVariant &argument : arguments) {
        if (!isDictionary(argument))
            continue;
        const QVariantMap dictionary = qdbus_cast<QVariantMap>(argument);
        for (const auto &[key, value] : dictionary.asKeyValueRange())
            types.insert(key, QString::fromLatin1(value.typeName()));
    }
    return types;
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
        m_replyVariantTypes = variantTypesOf(reply.arguments());
        Q_EMIT replied(reply.signature(), plainValues(reply.arguments()), reply.errorName());
    });
}

QString Counterpart::nameOwner(const QString &name)
{
    return m_connection.interface()->serviceOwner(name).value();
}

bool Counterpart::listen(const QString &interfaceName, const QString &member)
{
    return m_connection.connect({}, {}, interfaceName, member, this, SLOT(hear(QDBusMessage)));
}

void Counterpart::hear(const QDBusMessage &message)
{
    Q_EMIT heard(message.service(), message.path(), message.member(), message.signature(), plainValues(message.arguments()));
}

bool Counterpart::takeName(const QString &name)
{
    const QDBusReply<QDBusConnectionInterface::RegisterServiceReply> reply = m_connection.interface()->registerService(
        name, QDBusConnectionInterface::ReplaceExistingService, QDBusConnectionInterface::DontAllowReplacement);
    return reply.isValid() && reply.value() == QDBusConnectionInterface::ServiceRegistered;
}

void Counterpart::answerAt(const QString &path, const QVariantList &values)
{
    m_connection.registerVirtualObject(path, new Answer(this, values));
    m_paths.append(path);
}

void Counterpart::failAt(const QString &path, const QString &name, const QString &message)
{
    m_connection.registerVirtualObject(path, new Answer(this, std::nullopt, QPair(name, message)));
    m_paths.append(path);
}

void Counterpart::ignoreAt(const QString &path)
{
    m_connection.registerVirtualObject(path, new Answer(this, std::nullopt));
    m_paths.append(path);
}

namespace
{

struct ActionRow {
    QString id;
    QVariantMap properties;
};

QDBusArgument &operator<<(QDBusArgument &argument, const ActionRow &row)
{
    argument.beginStructure();
    argument << row.id << row.properties;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, ActionRow &row)
{
    argument.beginStructure();
    argument >> row.id >> row.properties;
    argument.endStructure();
    return argument;
}

// A list of strings goes over the bus as `as`, as a JavaScript array reaches here as a list of variants.
QVariantMap withStringLists(QVariantMap properties)
{
    for (auto &value : properties) {
        const QVariantList list = value.toList();
        if (value.metaType() != QMetaType::fromType<QVariantList>())
            continue;
        QStringList strings;
        for (const QVariant &item : list)
            strings.append(item.toString());
        value = strings;
    }
    return properties;
}

}

class Provider : public QDBusVirtualObject
{
public:
    explicit Provider(Counterpart *counterpart)
        : QDBusVirtualObject(counterpart)
        , m_counterpart(counterpart)
    {
        qDBusRegisterMetaType<ActionRow>();
        qDBusRegisterMetaType<QList<ActionRow>>();
    }

    QString introspect(const QString &) const override
    {
        return {};
    }

    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        m_counterpart->record(message);
        if (message.member() == u"ListActions"_s && m_hold)
            m_held.append(message);
        else if (message.member() == u"ListActions"_s)
            connection.send(message.createReply(QVariant::fromValue(m_rows)));
        else if (m_holdInvokes)
            m_heldInvokes.append(message);
        else if (m_failInvokes)
            connection.send(message.createErrorReply(u"org.rekta.Counterpart.Failed"_s, m_failMessage));
        else
            connection.send(message.createReply(QVariant(m_invokeAnswer)));
        return true;
    }

    void setActions(const QVariantList &actions)
    {
        m_rows.clear();
        for (const QVariant &action : actions) {
            const QVariantMap map = action.toMap();
            m_rows.append({map.value(u"id"_s).toString(), withStringLists(map.value(u"properties"_s).toMap())});
        }
    }

    void setFailInvokes(bool fail)
    {
        m_failInvokes = fail;
    }

    void setFailMessage(const QString &message)
    {
        m_failMessage = message;
    }

    void setInvokeAnswer(const QVariantMap &answer)
    {
        m_invokeAnswer = answer;
    }

    void setHoldInvokes(bool hold)
    {
        m_holdInvokes = hold;
    }

    void answerHeldInvokes(const QDBusConnection &connection)
    {
        for (const QDBusMessage &message : std::exchange(m_heldInvokes, {}))
            connection.send(message.createReply(QVariant(m_invokeAnswer)));
    }

    // Answers the ListActions calls held back, with the actions as they are now.
    void setHold(bool hold)
    {
        m_hold = hold;
    }

    void answerHeld(const QDBusConnection &connection)
    {
        for (const QDBusMessage &message : std::exchange(m_held, {}))
            connection.send(message.createReply(QVariant::fromValue(m_rows)));
    }

private:
    Counterpart *m_counterpart;
    QList<ActionRow> m_rows;
    bool m_failInvokes = false;
    QString m_failMessage = u"the provider failed"_s;
    bool m_hold = false;
    QList<QDBusMessage> m_held;
    QVariantMap m_invokeAnswer;
    bool m_holdInvokes = false;
    QList<QDBusMessage> m_heldInvokes;
};

void Counterpart::releaseName(const QString &name)
{
    m_connection.interface()->unregisterService(name);
    for (const QString &path : std::as_const(m_paths))
        m_connection.unregisterObject(path);
    m_paths.clear();
    // Only here is Provider complete, so only here does delete run its destructor.
    delete m_provider;
    m_provider = nullptr;
}

void Counterpart::provide(const QString &path, const QVariantList &actions)
{
    if (!m_provider) {
        m_provider = new Provider(this);
        m_connection.registerVirtualObject(path, m_provider);
        m_paths.append(path);
    }
    m_provider->setActions(actions);
}

void Counterpart::failInvokes(bool fail)
{
    if (m_provider)
        m_provider->setFailInvokes(fail);
}

void Counterpart::failInvokesWithMessage(const QString &message)
{
    if (m_provider)
        m_provider->setFailMessage(message);
}

void Counterpart::answerInvokesWith(const QVariantMap &answer)
{
    if (m_provider)
        m_provider->setInvokeAnswer(answer);
}

void Counterpart::holdInvokes(bool hold)
{
    if (m_provider)
        m_provider->setHoldInvokes(hold);
}

void Counterpart::answerHeldInvokes()
{
    if (m_provider)
        m_provider->answerHeldInvokes(m_connection);
}

void Counterpart::forgetCalls()
{
    m_callCounts.clear();
}

int Counterpart::callsTo(const QString &member) const
{
    return m_callCounts.value(member);
}

void Counterpart::flood(const QString &path, const QString &interfaceName, const QString &member, int count)
{
    for (int i = 1; i <= count; ++i)
        emitSignal(path, interfaceName, member, {QVariant(uint(i))});
}

void Counterpart::callFlood(const QString &service, const QString &path, const QString &interfaceName, const QString &member, int count)
{
    for (int i = 0; i < count; ++i)
        m_connection.send(QDBusMessage::createMethodCall(service, path, interfaceName, member));
}

QString Counterpart::uniqueName() const
{
    return m_connection.baseService();
}

void Counterpart::record(const QDBusMessage &message)
{
    m_callCounts[message.member()]++;
    m_lastCall = {
        {u"path"_s, message.path()},
        {u"interface"_s, message.interface()},
        {u"member"_s, message.member()},
        {u"args"_s, plainValues(message.arguments())},
    };
    m_lastSignature = message.signature();
    m_variantTypes = variantTypesOf(message.arguments());
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

void Counterpart::holdListings(bool hold)
{
    if (m_provider)
        m_provider->setHold(hold);
}

void Counterpart::answerHeldListings()
{
    if (m_provider)
        m_provider->answerHeld(m_connection);
}

void Counterpart::leaveName(const QString &name)
{
    m_connection.interface()->unregisterService(name);
}

void Counterpart::claimEchoName()
{
    m_connection.interface()->registerService(u"org.rekta.Counterpart"_s,
                                              QDBusConnectionInterface::ReplaceExistingService,
                                              QDBusConnectionInterface::AllowReplacement);
}

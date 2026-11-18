#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVirtualObject>
#include <QHash>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Provider;

// The other end of the bus for the tests of RektaShell.DBus, written against QtDBus alone. It owns
// org.rekta.Counterpart, echoes every call to /echo back (or fails when asked "Fail") and records what arrived; it
// sends and hears signals, calls methods, takes and answers names of others and asks the bus who owns a name.
class Counterpart : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // The last call to /echo or to a path answerAt() or ignoreAt() put up: {path, interface, member, args}, its arguments
    // as replied() gives values.
    Q_PROPERTY(QVariantMap lastCall READ lastCall NOTIFY echoed FINAL)
    // The signature of that call, read from the message on the wire.
    Q_PROPERTY(QString lastSignature READ lastSignature NOTIFY echoed FINAL)
    // The Qt types of the values in that call's a{sv} arguments, by key.
    Q_PROPERTY(QVariantMap variantTypes READ variantTypes NOTIFY echoed FINAL)
    // The Qt types of the values in the last reply's a{sv} arguments, by key.
    Q_PROPERTY(QVariantMap replyVariantTypes READ replyVariantTypes NOTIFY replied FINAL)

public:
    explicit Counterpart(QObject *parent = nullptr);
    ~Counterpart() override;

    Q_INVOKABLE void emitSignal(const QString &path, const QString &interfaceName, const QString &member, const QVariantList &args);
    // Replies with replied(), containers as lists and maps and variants unpacked; an error reply carries its message as
    // the only value.
    Q_INVOKABLE void call(const QString &service,
                          const QString &path,
                          const QString &interfaceName,
                          const QString &member,
                          const QVariantList &args);
    // The unique name owning name, or "" when nobody does.
    Q_INVOKABLE QString nameOwner(const QString &name);
    // Reports each signal of that interface and member, from any sender, with heard(), its values read as a reply's.
    Q_INVOKABLE bool listen(const QString &interfaceName, const QString &member);
    // Takes name from its owner for good, as a program that pushes the shell aside would; false when it cannot.
    Q_INVOKABLE bool takeName(const QString &name);
    // Gives name up and drops what answerAt() or ignoreAt() put up.
    Q_INVOKABLE void releaseName(const QString &name);
    // Gives name up and nothing else: what a provider put up stays and may still answer.
    Q_INVOKABLE void leaveName(const QString &name);
    // Takes org.rekta.Counterpart (what /echo answers at) from another counterpart in the process.
    Q_INVOKABLE void claimEchoName();
    // Every call to path is recorded and answered with these values, typed as QtDBus types them.
    Q_INVOKABLE void answerAt(const QString &path, const QVariantList &values);
    // Every call to path is recorded and stays without an answer.
    Q_INVOKABLE void ignoreAt(const QString &path);
    // Puts up a provider of rekta.Actions1 at path: ListActions answers `actions`, a list of {id, properties} (a list of
    // strings in a property goes as `as`), and Invoke an empty a{sv}, or an error while failInvokes(true). Calling it again
    // replaces the actions. Every call is recorded.
    Q_INVOKABLE void provide(const QString &path, const QVariantList &actions);
    Q_INVOKABLE void failInvokes(bool fail);
    // Holds the ListActions calls unanswered while true; answerHeldListings() answers them, with the actions then.
    Q_INVOKABLE void holdListings(bool hold);
    Q_INVOKABLE void answerHeldListings();
    // How many calls with that member arrived, at any path.
    Q_INVOKABLE int callsTo(const QString &member) const;
    Q_INVOKABLE void forgetCalls();
    // Sends count signals in a row, numbered from 1.
    Q_INVOKABLE void flood(const QString &path, const QString &interfaceName, const QString &member, int count);
    // Sends count calls in a row without waiting for their answers.
    Q_INVOKABLE void callFlood(const QString &service, const QString &path, const QString &interfaceName, const QString &member, int count);
    Q_INVOKABLE QString uniqueName() const;

    QVariantMap lastCall() const
    {
        return m_lastCall;
    }
    QString lastSignature() const
    {
        return m_lastSignature;
    }
    QVariantMap variantTypes() const
    {
        return m_variantTypes;
    }
    QVariantMap replyVariantTypes() const
    {
        return m_replyVariantTypes;
    }

    void record(const QDBusMessage &message);

Q_SIGNALS:
    void echoed();
    void replied(const QString &signature, const QVariantList &values, const QString &error);
    void heard(const QString &sender, const QString &path, const QString &member, const QString &signature, const QVariantList &values);

private Q_SLOTS:
    void hear(const QDBusMessage &message);

private:
    QStringList m_paths;
    QDBusConnection m_connection;
    QVariantMap m_lastCall;
    QString m_lastSignature;
    QVariantMap m_variantTypes;
    QVariantMap m_replyVariantTypes;
    QHash<QString, int> m_callCounts;
    Provider *m_provider = nullptr;
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

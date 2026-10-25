#pragma once

#include <QString>
#include <QStringList>
#include <QVariant>

#include <optional>

// D-Bus values for QML: JavaScript values go out typed by a D-Bus signature; values that arrive come back as plain
// lists, maps, strings and numbers.
namespace Marshalling
{

// The complete types of a signature, one per argument, or nothing when the signature is not valid.
std::optional<QStringList> completeTypes(const QString &signature);

struct Encoded {
    QVariantList arguments;
    QString error;
};

Encoded encode(const QVariantList &values, const QString &signature);

QVariantList decode(const QVariantList &arguments);

}

#include "marshalling.h"

#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusSignature>
#include <QDBusVariant>

using namespace Qt::StringLiterals;

namespace
{

// The limits of the D-Bus specification: 255 characters, 32 arrays and 32 structs inside each other. Dictionary entries
// count with the structs, so no value lies inside more than the 64 containers the bus accepts. Beyond them libdbus aborts
// the process or the bus drops the connection, so nothing beyond them may reach it.
constexpr qsizetype maxSignatureLength = 255;
constexpr int maxArrayNesting = 32;
constexpr int maxBracketNesting = 32;
const QString basicTypes = u"ybnqiuxtdsog"_s;

// The arrays and the brackets (structs and dictionary entries) around a type.
struct Nesting {
    int arrays = 0;
    int brackets = 0;
};

// The type code at index, or none past the end.
QChar codeAt(const QString &signature, qsizetype index)
{
    return index < signature.size() ? signature[index] : QChar();
}

qsizetype endOfType(const QString &signature, qsizetype start, Nesting nesting);

qsizetype endOfStruct(const QString &signature, qsizetype open, Nesting nesting)
{
    if (++nesting.brackets > maxBracketNesting || codeAt(signature, open + 1) == u')')
        return -1;
    qsizetype end = open + 1;
    while (end != -1 && end < signature.size() && signature[end] != u')')
        end = endOfType(signature, end, nesting);
    return end == -1 || end >= signature.size() ? -1 : end + 1;
}

// A dictionary entry holds a basic key and one value.
qsizetype endOfDictEntry(const QString &signature, qsizetype open, Nesting nesting)
{
    if (++nesting.brackets > maxBracketNesting || !basicTypes.contains(codeAt(signature, open + 1)))
        return -1;
    const qsizetype end = endOfType(signature, open + 2, nesting);
    return end != -1 && codeAt(signature, end) == u'}' ? end + 1 : -1;
}

qsizetype endOfArray(const QString &signature, qsizetype start, Nesting nesting)
{
    if (++nesting.arrays > maxArrayNesting)
        return -1;
    if (codeAt(signature, start + 1) == u'{')
        return endOfDictEntry(signature, start + 1, nesting);
    return endOfType(signature, start + 1, nesting);
}

qsizetype endOfType(const QString &signature, qsizetype start, Nesting nesting)
{
    const QChar code = codeAt(signature, start);
    if (basicTypes.contains(code) || code == u'v')
        return start + 1;
    if (code == u'(')
        return endOfStruct(signature, start, nesting);
    if (code == u'a')
        return endOfArray(signature, start, nesting);
    return -1;
}

// QDBusArgument opens an array only for a registered element type, so one placeholder type stands in for the element
// signature of each array as it is opened.
struct ArrayElement {
};

void beginArray(QDBusArgument &out, const QString &elementType)
{
    const QMetaType placeholder = QMetaType::fromType<ArrayElement>();
    QDBusMetaType::registerCustomType(placeholder, elementType.toLatin1());
    out.beginArray(placeholder);
}

// A JavaScript value in a variant has no signature to follow, so it goes out as the D-Bus type closest to its own.
// ponytail: whole numbers go out as i and others as d; a typed variant value once a callee needs u, x or t there.
QString naturalType(const QVariant &value)
{
    switch (value.metaType().id()) {
    case QMetaType::Bool:
        return u"b"_s;
    case QMetaType::Int:
        return u"i"_s;
    case QMetaType::Double:
        return u"d"_s;
    case QMetaType::QString:
        return u"s"_s;
    case QMetaType::QVariantList:
        return u"av"_s;
    case QMetaType::QVariantMap:
        return u"a{sv}"_s;
    }
    return {};
}

// Writes values of any signature. A value that does not fit its type sets the error and goes out as a stand-in of that
// type, so every container still closes and the half-written message is simply dropped.
class Writer
{
public:
    QString error;

    void write(QDBusArgument &out, const QVariant &value, const QString &type)
    {
        if (!value.isValid() || value.isNull())
            fail(u"a value for %1 is missing"_s.arg(type));
        if (type == u"v")
            writeVariant(out, value);
        else if (type.startsWith(u'('))
            writeStruct(out, value, type);
        else if (type.startsWith(u"a{"))
            writeDictionary(out, value, type.mid(1));
        else if (type.startsWith(u'a'))
            writeArray(out, value, type.mid(1));
        else
            writeBasic(out, value, type.front());
    }

private:
    // The containers around the value being written. Only values in variants can lie deeper than their signature allows.
    int m_containers = 0;

    void fail(const QString &message)
    {
        if (error.isEmpty())
            error = message;
    }

    void writeVariant(QDBusArgument &out, const QVariant &value)
    {
        QString type = naturalType(value);
        if (type.isEmpty()) {
            fail(u"%1 cannot go into a variant"_s.arg(QString::fromLatin1(value.typeName())));
            type = u"s"_s;
        }
        if (m_containers >= maxArrayNesting + maxBracketNesting) {
            fail(u"a value in a variant lies inside more than %1 containers"_s.arg(m_containers));
            type = u"s"_s;
        }
        QDBusArgument content;
        ++m_containers;
        write(content, value, type);
        --m_containers;
        out << QDBusVariant(QVariant::fromValue(content));
    }

    void writeStruct(QDBusArgument &out, const QVariant &value, const QString &type)
    {
        const QStringList memberTypes = *Marshalling::completeTypes(type.sliced(1, type.size() - 2));
        const QVariantList members = value.toList();
        if (members.size() != memberTypes.size())
            fail(u"%1 needs %2 values, not %3"_s.arg(type).arg(memberTypes.size()).arg(members.size()));
        ++m_containers;
        out.beginStructure();
        for (qsizetype i = 0; i < memberTypes.size(); ++i)
            write(out, members.value(i), memberTypes[i]);
        out.endStructure();
        --m_containers;
    }

    void writeDictionary(QDBusArgument &out, const QVariant &value, const QString &entryType)
    {
        if (!value.canConvert<QVariantMap>())
            fail(u"a%1 needs an object"_s.arg(entryType));
        const QString keyType = entryType.sliced(1, 1);
        const QString valueType = entryType.sliced(2, entryType.size() - 3);
        const QVariantMap entries = value.toMap();
        // The array and its entry.
        m_containers += 2;
        beginArray(out, entryType);
        for (const auto &[key, entryValue] : entries.asKeyValueRange()) {
            out.beginMapEntry();
            write(out, key, keyType);
            write(out, entryValue, valueType);
            out.endMapEntry();
        }
        out.endArray();
        m_containers -= 2;
    }

    void writeArray(QDBusArgument &out, const QVariant &value, const QString &elementType)
    {
        if (!value.canConvert<QVariantList>())
            fail(u"a%1 needs an array"_s.arg(elementType));
        ++m_containers;
        beginArray(out, elementType);
        for (const QVariant &element : value.toList())
            write(out, element, elementType);
        out.endArray();
        --m_containers;
    }

    void writeBasic(QDBusArgument &out, const QVariant &value, QChar code)
    {
        if (code == u's')
            out << value.toString();
        else if (code == u'b')
            out << value.toBool();
        else if (code == u'o')
            writeObjectPath(out, value.toString());
        else if (code == u'g')
            writeSignature(out, value.toString());
        else
            writeNumber(out, value, code);
    }

    void writeObjectPath(QDBusArgument &out, const QString &path)
    {
        const QDBusObjectPath objectPath(path);
        if (objectPath.path().isEmpty())
            fail(u"%1 is not an object path"_s.arg(path));
        out << (objectPath.path().isEmpty() ? QDBusObjectPath(u"/"_s) : objectPath);
    }

    void writeSignature(QDBusArgument &out, const QString &signature)
    {
        const bool valid = Marshalling::completeTypes(signature).has_value();
        if (!valid)
            fail(u"%1 is not a signature"_s.arg(signature));
        out << QDBusSignature(valid ? signature : QString());
    }

    void writeNumber(QDBusArgument &out, const QVariant &value, QChar code)
    {
        bool isNumber = false;
        const qlonglong whole = value.toLongLong(&isNumber);
        if (code == u'd')
            out << value.toDouble(&isNumber);
        else if (code == u't')
            out << value.toULongLong(&isNumber);
        else if (code == u'y')
            out << uchar(whole);
        else if (code == u'n')
            out << short(whole);
        else if (code == u'q')
            out << ushort(whole);
        else if (code == u'i')
            out << int(whole);
        else if (code == u'u')
            out << uint(whole);
        else
            out << whole;
        if (!isNumber)
            fail(u"%1 is not a number for %2"_s.arg(value.toString(), QString(code)));
    }
};

QVariant decodeValue(const QVariant &value);

QVariantList decodeElements(const QDBusArgument &argument)
{
    QVariantList elements;
    while (!argument.atEnd())
        elements.append(decodeValue(argument.asVariant()));
    return elements;
}

QVariantMap decodeMap(const QDBusArgument &argument)
{
    QVariantMap map;
    argument.beginMap();
    while (!argument.atEnd()) {
        argument.beginMapEntry();
        const QString key = decodeValue(argument.asVariant()).toString();
        map.insert(key, decodeValue(argument.asVariant()));
        argument.endMapEntry();
    }
    argument.endMap();
    return map;
}

QVariant decodeArgument(const QDBusArgument &argument)
{
    switch (argument.currentType()) {
    case QDBusArgument::MapType:
        return decodeMap(argument);
    case QDBusArgument::ArrayType: {
        argument.beginArray();
        const QVariantList elements = decodeElements(argument);
        argument.endArray();
        return elements;
    }
    case QDBusArgument::StructureType: {
        argument.beginStructure();
        const QVariantList members = decodeElements(argument);
        argument.endStructure();
        return members;
    }
    default:
        return decodeValue(argument.asVariant());
    }
}

QVariantList decodeBytes(const QByteArray &bytes)
{
    QVariantList numbers;
    for (const char byte : bytes)
        numbers.append(uchar(byte));
    return numbers;
}

QVariant decodeValue(const QVariant &value)
{
    const QMetaType type = value.metaType();
    if (type == QMetaType::fromType<QDBusArgument>())
        return decodeArgument(value.value<QDBusArgument>());
    if (type == QMetaType::fromType<QDBusVariant>())
        return decodeValue(value.value<QDBusVariant>().variant());
    if (type == QMetaType::fromType<QDBusObjectPath>())
        return value.value<QDBusObjectPath>().path();
    if (type == QMetaType::fromType<QDBusSignature>())
        return value.value<QDBusSignature>().signature();
    if (type == QMetaType::fromType<QByteArray>())
        return decodeBytes(value.toByteArray());
    return value;
}

}

namespace Marshalling
{

std::optional<QStringList> completeTypes(const QString &signature)
{
    if (signature.size() > maxSignatureLength)
        return std::nullopt;
    QStringList types;
    for (qsizetype start = 0; start < signature.size();) {
        const qsizetype end = endOfType(signature, start, {});
        if (end == -1)
            return std::nullopt;
        types.append(signature.sliced(start, end - start));
        start = end;
    }
    return types;
}

Encoded encode(const QVariantList &values, const QString &signature)
{
    const std::optional<QStringList> types = completeTypes(signature);
    if (!types)
        return {{}, u"%1 is not a valid D-Bus signature"_s.arg(signature)};
    if (types->size() != values.size())
        return {{}, u"the signature %1 needs %2 values, not %3"_s.arg(signature).arg(types->size()).arg(values.size())};
    Writer writer;
    QVariantList arguments;
    for (qsizetype i = 0; i < values.size(); ++i) {
        QDBusArgument argument;
        writer.write(argument, values[i], types->at(i));
        arguments.append(QVariant::fromValue(argument));
    }
    if (!writer.error.isEmpty())
        return {{}, writer.error};
    return {arguments, {}};
}

QVariantList decode(const QVariantList &arguments)
{
    QVariantList values;
    for (const QVariant &argument : arguments)
        values.append(decodeValue(argument));
    return values;
}

}

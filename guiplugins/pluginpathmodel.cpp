/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#include "pluginpathmodel.h"

#include "backendconnection.h"

#include <veutil/qt/ve_qitem.hpp>

#include <QSet>

#include <algorithm>
#include <chrono>

namespace Victron {
namespace GuiPlugins {

/*
	The rows come from the tree of backend items below uid. That tree also has items that exist
	only because the GUI asked for a path, whether the system has that path or not. So a child is
	listed only when its state shows that the system gave it a value, or when an item below it
	does. A child such as "Dc" has no value of its own, so every item below uid is watched.

	The model reads only the state of an item, never its value: reading the value would ask the
	system for it.

	Rows are inserted and removed, not reset, so that a view keeps the delegates of the rows that
	stay.

	Changes often come in bursts, such as when the GUI connects and the system sends every path.
	So a change starts a short timer, and the list is updated once when it fires. Later changes
	do not restart the timer, so a steady stream of changes still updates the list.

	serviceType and path name a uid as on a PluginDataItem without a deviceInstance. uid is empty
	while only one of them is set, so nothing is listed while QML assigns them. When both are
	empty, uid is left alone, so that the plugin can set it.

	The D-Bus and MQTT backends never delete items, but the mock backend deletes the items of a
	device that it removes. If the item at uid is deleted, the model creates it again, so that it
	sees the paths if they come back.
*/

namespace {

bool isListed(const VeQItem *item)
{
	switch (item->getState()) {
	case VeQItem::Synchronized:
	case VeQItem::Storing:
	case VeQItem::Preview:
		return true;
	default:
		break;
	}
	const VeQItem::Children &children = item->itemChildren();
	for (auto it = children.constBegin(); it != children.constEnd(); ++it) {
		if (isListed(it.value())) {
			return true;
		}
	}
	return false;
}

bool nameLessThan(const QString &left, const QString &right)
{
	bool leftIsNumber = false;
	bool rightIsNumber = false;
	const qulonglong leftNumber = left.toULongLong(&leftIsNumber);
	const qulonglong rightNumber = right.toULongLong(&rightIsNumber);
	if (leftIsNumber != rightIsNumber) {
		return leftIsNumber;
	}
	if (leftIsNumber && leftNumber != rightNumber) {
		return leftNumber < rightNumber;
	}
	const int compared = left.compare(right, Qt::CaseInsensitive);
	return compared != 0 ? compared < 0 : left < right;
}

} // namespace

PluginPathModel::PluginPathModel(QObject *parent)
	: QAbstractListModel(parent)
{
	m_updateTimer.setSingleShot(true);
	m_updateTimer.setInterval(std::chrono::milliseconds(100));
	connect(&m_updateTimer, &QTimer::timeout, this, &PluginPathModel::update);
}

QString PluginPathModel::uid() const
{
	return m_uid;
}

void PluginPathModel::setUid(const QString &uid)
{
	if (m_uid == uid) {
		return;
	}
	m_uid = uid;
	m_updateTimer.stop();

	if (m_root) {
		unwatchItem(m_root);
	}
	findRoot();

	const int previous = m_names.count();
	beginResetModel();
	m_names = listedNames();
	endResetModel();
	emit uidChanged();
	if (m_names.count() != previous) {
		emit countChanged();
	}
}

void PluginPathModel::findRoot()
{
	QString rootUid = m_uid;
	while (rootUid.endsWith(u'/')) {
		rootUid.chop(1);
	}
	// Create the item if it does not exist yet, as a VeQuickItem does, so that new children are seen.
	m_root = rootUid.isEmpty() ? nullptr : VeQItems::getRoot()->itemGetOrCreate(rootUid, true, false);
	m_rootUid = m_root ? m_root->uniqueId() : QString();
	if (m_root) {
		watchItem(m_root);
		connect(m_root, &QObject::destroyed, this, &PluginPathModel::rootDestroyed);
	}
}

QString PluginPathModel::serviceType() const
{
	return m_serviceType;
}

void PluginPathModel::setServiceType(const QString &serviceType)
{
	if (m_serviceType != serviceType) {
		m_serviceType = serviceType;
		emit serviceTypeChanged();
		updateResolvedUid();
	}
}

QString PluginPathModel::path() const
{
	return m_path;
}

void PluginPathModel::setPath(const QString &path)
{
	if (m_path != path) {
		m_path = path;
		emit pathChanged();
		updateResolvedUid();
	}
}

void PluginPathModel::updateResolvedUid()
{
	if (m_serviceType.isEmpty() && m_path.isEmpty()) {
		return;
	}
	if (m_serviceType.isEmpty() || m_path.isEmpty()) {
		setUid(QString());
		return;
	}
	const QString serviceUid = VenusOS::BackendConnection::create()->serviceUidForType(m_serviceType);
	const QString relativePath = m_path.startsWith(u'/') ? m_path.mid(1) : m_path;
	setUid(relativePath.isEmpty() ? serviceUid : serviceUid + u'/' + relativePath);
}

int PluginPathModel::count() const
{
	return m_names.count();
}

QString PluginPathModel::nameAt(int index) const
{
	return index >= 0 && index < m_names.count() ? m_names.at(index) : QString();
}

QString PluginPathModel::uidAt(int index) const
{
	return index >= 0 && index < m_names.count() ? m_rootUid + u'/' + m_names.at(index) : QString();
}

int PluginPathModel::rowCount(const QModelIndex &parent) const
{
	return parent.isValid() ? 0 : m_names.count();
}

QVariant PluginPathModel::data(const QModelIndex &index, int role) const
{
	if (index.column() != 0 || index.row() < 0 || index.row() >= m_names.count()) {
		return QVariant();
	}
	switch (role) {
	case NameRole:
		return nameAt(index.row());
	case UidRole:
		return uidAt(index.row());
	default:
		return QVariant();
	}
}

QHash<int, QByteArray> PluginPathModel::roleNames() const
{
	return {
		{ NameRole, "name" },
		{ UidRole, "uid" },
	};
}

void PluginPathModel::watchItem(VeQItem *item)
{
	connect(item, &VeQItem::childAdded, this, &PluginPathModel::childAdded, Qt::UniqueConnection);
	connect(item, &VeQItem::childRemoved, this, &PluginPathModel::scheduleUpdate, Qt::UniqueConnection);
	connect(item, &VeQItem::stateChanged, this, &PluginPathModel::scheduleUpdate, Qt::UniqueConnection);
	const VeQItem::Children &children = item->itemChildren();
	for (auto it = children.constBegin(); it != children.constEnd(); ++it) {
		watchItem(it.value());
	}
}

void PluginPathModel::unwatchItem(VeQItem *item)
{
	item->disconnect(this);
	const VeQItem::Children &children = item->itemChildren();
	for (auto it = children.constBegin(); it != children.constEnd(); ++it) {
		unwatchItem(it.value());
	}
}

void PluginPathModel::childAdded(VeQItem *child)
{
	watchItem(child);
	scheduleUpdate();
}

void PluginPathModel::scheduleUpdate()
{
	if (!m_updateTimer.isActive()) {
		m_updateTimer.start();
	}
}

void PluginPathModel::rootDestroyed()
{
	m_updateTimer.stop();
	if (!m_names.isEmpty()) {
		beginResetModel();
		m_names.clear();
		endResetModel();
		emit countChanged();
	}
	// Wait until the backend has finished deleting the items.
	QMetaObject::invokeMethod(this, &PluginPathModel::findDeletedRoot, Qt::QueuedConnection);
}

void PluginPathModel::findDeletedRoot()
{
	// If uid changed meanwhile, setUid() found its root already.
	if (m_root) {
		return;
	}
	findRoot();
	scheduleUpdate();
}

QStringList PluginPathModel::listedNames() const
{
	QStringList names;
	if (m_root) {
		const VeQItem::Children &children = m_root->itemChildren();
		for (auto it = children.constBegin(); it != children.constEnd(); ++it) {
			if (isListed(it.value())) {
				names.append(it.key());
			}
		}
	}
	std::sort(names.begin(), names.end(), nameLessThan);
	return names;
}

void PluginPathModel::update()
{
	const int previous = m_names.count();
	const QStringList names = listedNames();
	const QSet<QString> listed(names.cbegin(), names.cend());
	for (int row = m_names.count() - 1; row >= 0; --row) {
		if (!listed.contains(m_names.at(row))) {
			beginRemoveRows(QModelIndex(), row, row);
			m_names.removeAt(row);
			endRemoveRows();
		}
	}
	// The rows left are in the same order as in names, so each missing name is inserted at its
	// index in names.
	for (int row = 0; row < names.count(); ++row) {
		if (row < m_names.count() && m_names.at(row) == names.at(row)) {
			continue;
		}
		beginInsertRows(QModelIndex(), row, row);
		m_names.insert(row, names.at(row));
		endInsertRows();
	}
	if (m_names.count() != previous) {
		emit countChanged();
	}
}

} // namespace GuiPlugins
} // namespace Victron

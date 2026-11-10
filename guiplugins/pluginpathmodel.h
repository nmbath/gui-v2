/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#ifndef VICTRON_GUIPLUGINS_PLUGINPATHMODEL_H
#define VICTRON_GUIPLUGINS_PLUGINPATHMODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <qqmlintegration.h>

class VeQItem;

namespace Victron {
namespace GuiPlugins {

/*
	The paths directly below a uid, for plugins, such as the paths of a device.

	Set uid, such as a device's service uid, or set serviceType and path to name a uid on a service
	with one instance, as on a PluginDataItem. Each row has the name of a path below it, such as
	"Dc", and the uid of that path. Only the paths that the system has are listed.
*/
class PluginPathModel : public QAbstractListModel
{
	Q_OBJECT
	QML_ELEMENT
	Q_PROPERTY(QString uid READ uid WRITE setUid NOTIFY uidChanged FINAL)
	Q_PROPERTY(QString serviceType READ serviceType WRITE setServiceType NOTIFY serviceTypeChanged FINAL)
	Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged FINAL)
	Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
	explicit PluginPathModel(QObject *parent = nullptr);

	QString uid() const;
	void setUid(const QString &uid);

	QString serviceType() const;
	void setServiceType(const QString &serviceType);

	QString path() const;
	void setPath(const QString &path);

	int count() const;

	Q_INVOKABLE QString nameAt(int index) const;
	Q_INVOKABLE QString uidAt(int index) const;

	int rowCount(const QModelIndex &parent = QModelIndex()) const override;
	QVariant data(const QModelIndex &index, int role) const override;
	QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
	void uidChanged();
	void serviceTypeChanged();
	void pathChanged();
	void countChanged();

private:
	enum Role {
		NameRole = Qt::UserRole,
		UidRole
	};

	void updateResolvedUid();
	void findRoot();
	void watchItem(VeQItem *item);
	void unwatchItem(VeQItem *item);
	void childAdded(VeQItem *child);
	void scheduleUpdate();
	void rootDestroyed();
	void findDeletedRoot();
	QStringList listedNames() const;
	void update();

	QPointer<VeQItem> m_root;
	QString m_uid;
	QString m_rootUid;
	QString m_serviceType;
	QString m_path;
	QStringList m_names;
	QTimer m_updateTimer;
};

} // namespace GuiPlugins
} // namespace Victron

#endif // VICTRON_GUIPLUGINS_PLUGINPATHMODEL_H

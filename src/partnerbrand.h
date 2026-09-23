/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#ifndef VICTRON_VENUSOS_GUI_V2_PARTNERBRAND_H
#define VICTRON_VENUSOS_GUI_V2_PARTNERBRAND_H

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/QJSEngine>
#include <QtQml/QQmlEngine>
#include <qqmlintegration.h>

namespace Victron {
namespace VenusOS {

class PartnerBrand : public QObject
{
	Q_OBJECT
	QML_ELEMENT
	QML_SINGLETON

	Q_PROPERTY(bool active READ active NOTIFY changed FINAL)
	Q_PROPERTY(QString id READ id NOTIFY changed FINAL)
	Q_PROPERTY(QString displayName READ displayName NOTIFY changed FINAL)
	Q_PROPERTY(QUrl logo READ logo NOTIFY changed FINAL)
	Q_PROPERTY(QUrl logoDark READ logoDark NOTIFY changed FINAL)
	Q_PROPERTY(QUrl logoLight READ logoLight NOTIFY changed FINAL)
	Q_PROPERTY(QUrl splashLogo READ splashLogo NOTIFY changed FINAL)
	Q_PROPERTY(QUrl bootstrapLogoDark READ bootstrapLogoDark NOTIFY changed FINAL)
	Q_PROPERTY(QUrl bootstrapLogoLight READ bootstrapLogoLight NOTIFY changed FINAL)
	Q_PROPERTY(QUrl bootstrapSplashLogo READ bootstrapSplashLogo NOTIFY changed FINAL)
	Q_PROPERTY(QString version READ version NOTIFY changed FINAL)
	Q_PROPERTY(QString attribution READ attribution NOTIFY changed FINAL)

public:
	// Deliberately not default-constructible. QML must obtain the same singleton
	// instance used by GuiPluginLoader through create(), otherwise branding state
	// applied before the UI is constructed is lost in a second QML-owned object.
	explicit PartnerBrand(QObject *parent);
	static PartnerBrand *create(QQmlEngine *engine = nullptr, QJSEngine *jsEngine = nullptr);

	bool active() const { return m_active; }
	QString id() const { return m_id; }
	QString displayName() const { return m_displayName; }
	QUrl logo() const { return m_logo; }
	QUrl logoDark() const { return m_logoDark; }
	QUrl logoLight() const { return m_logoLight; }
	QUrl splashLogo() const { return m_splashLogo; }
	QUrl bootstrapLogoDark() const { return m_bootstrapLogoDark; }
	QUrl bootstrapLogoLight() const { return m_bootstrapLogoLight; }
	QUrl bootstrapSplashLogo() const { return m_bootstrapSplashLogo; }
	QString version() const { return m_version; }
	QString attribution() const { return m_attribution; }

	bool apply(const QString &pluginName, const QString &pluginVersion, const QVariantMap &definition);
	void clear();

Q_SIGNALS:
	void changed();

private:
	bool m_active = false;
	QString m_id;
	QString m_displayName;
	QUrl m_logo;
	QUrl m_logoDark;
	QUrl m_logoLight;
	QUrl m_splashLogo;
	QUrl m_bootstrapLogoDark;
	QUrl m_bootstrapLogoLight;
	QUrl m_bootstrapSplashLogo;
	QString m_version;
	QString m_attribution;
};

} // namespace VenusOS
} // namespace Victron

#endif // VICTRON_VENUSOS_GUI_V2_PARTNERBRAND_H

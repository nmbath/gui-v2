/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#include "partnerbrand.h"
#include "logging.h"

#if defined(VENUS_WEBASSEMBLY_BUILD)
#include <cstdlib>
#include <emscripten.h>

EM_JS(char *, getPartnerBootstrapLogoUtf8, (const char *fieldUtf8), {
	const field = UTF8ToString(fieldUtf8);
	const value = window.guiV2PartnerBranding?.[field];
	if (typeof value !== 'string' || !value) return 0;
	const length = lengthBytesUTF8(value) + 1;
	const result = _malloc(length);
	stringToUTF8(value, result, length);
	return result;
});
#endif

using namespace Victron::VenusOS;

PartnerBrand::PartnerBrand(QObject *parent)
	: QObject(parent)
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	auto bootstrapLogo = [](const char *field) {
		char *value = getPartnerBootstrapLogoUtf8(field);
		if (!value) {
			return QUrl();
		}
		const QUrl result(QString::fromUtf8(value));
		std::free(value);
		return result;
	};
	m_bootstrapLogoDark = bootstrapLogo("logoDark");
	m_bootstrapLogoLight = bootstrapLogo("logoLight");
	m_bootstrapSplashLogo = bootstrapLogo("splashLogo");
#endif
}

PartnerBrand *PartnerBrand::create(QQmlEngine *, QJSEngine *)
{
	static PartnerBrand *instance = new PartnerBrand(nullptr);
	return instance;
}

bool PartnerBrand::apply(const QString &pluginName, const QString &pluginVersion, const QVariantMap &definition)
{
	const QString resourcePrefix = QStringLiteral("qrc:/%1/").arg(pluginName);
	auto ownedUrl = [&definition, &resourcePrefix](const QString &field, QUrl *url) -> bool {
		const QString value = definition.value(field).toString();
		if (value.isEmpty()) {
			*url = QUrl();
			return true;
		}
		if (!value.startsWith(resourcePrefix)) {
			return false;
		}
		*url = QUrl(value);
		return url->isValid();
	};

	QUrl logo;
	QUrl logoDark;
	QUrl logoLight;
	QUrl splashLogo;
	if (!ownedUrl(QStringLiteral("logo"), &logo)
			|| !ownedUrl(QStringLiteral("logoDark"), &logoDark)
			|| !ownedUrl(QStringLiteral("logoLight"), &logoLight)
			|| !ownedUrl(QStringLiteral("splashLogo"), &splashLogo)) {
		qCWarning(venusGui) << "Rejecting partner branding with asset outside plugin resources:" << pluginName;
		return false;
	}

	m_active = true;
	m_id = definition.value(QStringLiteral("id"), pluginName).toString();
	m_displayName = definition.value(QStringLiteral("displayName"), pluginName).toString();
	m_logo = logo;
	m_logoDark = logoDark;
	m_logoLight = logoLight;
	m_splashLogo = splashLogo;
	m_bootstrapLogoDark = QUrl();
	m_bootstrapLogoLight = QUrl();
	m_bootstrapSplashLogo = QUrl();
	m_version = pluginVersion;
	m_attribution = definition.value(QStringLiteral("attribution")).toString();
	Q_EMIT changed();
	return true;
}

void PartnerBrand::clear()
{
	if (!m_active && m_bootstrapLogoDark.isEmpty()
			&& m_bootstrapLogoLight.isEmpty() && m_bootstrapSplashLogo.isEmpty()) {
		return;
	}
	m_active = false;
	m_id.clear();
	m_displayName.clear();
	m_logo = QUrl();
	m_logoDark = QUrl();
	m_logoLight = QUrl();
	m_splashLogo = QUrl();
	m_bootstrapLogoDark = QUrl();
	m_bootstrapLogoLight = QUrl();
	m_bootstrapSplashLogo = QUrl();
	m_version.clear();
	m_attribution.clear();
	Q_EMIT changed();
}

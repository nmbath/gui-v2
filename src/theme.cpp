/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#include "theme.h"
#include "logging.h"
#include <QInputMethod>
#include <QSet>

using namespace Victron::VenusOS;

// Global pointer to current theme instance
static Victron::VenusOS::Theme *g_themeInstance = nullptr;

#if defined(VENUS_WEBASSEMBLY_BUILD)
#include <emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>

EM_JS(int, getScreenWidth, (), {
	return screen.width;
});

EM_JS(int, getScreenHeight, (), {
	return screen.height;
});

EM_JS(int, getWindowHeight, (), {
	return window.innerHeight;
});

EM_JS(int, getVisualViewportHeight, (), {
	return window.visualViewport ? window.visualViewport.height : window.innerHeight;
});

EM_JS(int, getVisualViewportOffsetTop, (), {
	return window.visualViewport ? window.visualViewport.offsetTop : 0;
});

#endif

Theme::Theme(QObject *parent) : QObject(parent)
{
	g_themeInstance = this;
#if defined(VENUS_WEBASSEMBLY_BUILD)
	// 5"-6" Smartphones have 320 - 480 CSS independent pixel wide screens.
	if (getScreenHeight() > getScreenWidth()) {
		setScreenSize(Victron::VenusOS::Theme::Portrait);
	} else {
		setScreenSize(getScreenWidth() >= 480
			? Victron::VenusOS::Theme::SevenInch
			: Victron::VenusOS::Theme::FiveInch);
	}

	setWindowHeight(getWindowHeight());
	setVisualViewportHeight(getVisualViewportHeight());
	setVisualViewportOffsetTop(getVisualViewportOffsetTop());

	// Detect current color scheme and listen for changes
	emscripten::val mql = emscripten::val::global("window").call<emscripten::val>("matchMedia", std::string("(prefers-color-scheme: dark)"));
	bool isSystemSchemeDark = mql["matches"].as<bool>();

	setSystemColorScheme(isSystemSchemeDark ? Victron::VenusOS::Theme::SystemColorSchemeDark
								: Victron::VenusOS::Theme::SystemColorSchemeLight);

	// Sets the initial color to the same as the HTML loading screen until the right setting is available and applied
	// This prevents changing color scheme too often during startup
	setColorScheme(isSystemSchemeDark ? Victron::VenusOS::Theme::Dark
								: Victron::VenusOS::Theme::Light);

	// Register JavaScript listener for dynamic updates
	mql.call<void>("addEventListener", std::string("change"), emscripten::val::module_property("jsSystemColorSchemeChanged"));
#else
	const QSizeF physicalScreenSize = QGuiApplication::primaryScreen()->physicalSize();
	const int screenDiagonalMm = static_cast<int>(sqrt((physicalScreenSize.width() * physicalScreenSize.width())
		+ (physicalScreenSize.height() * physicalScreenSize.height())));
	setScreenSize((round(screenDiagonalMm / 10 / 2.5) == 7)
		? Victron::VenusOS::Theme::SevenInch
		: Victron::VenusOS::Theme::FiveInch);

	if (QInputMethod *inputMethod = QGuiApplication::inputMethod()) {
		connect(inputMethod, &QInputMethod::keyboardRectangleChanged, this, &Theme::updateViewportAndKeyboardProperties);
		connect(inputMethod, &QInputMethod::visibleChanged, this, &Theme::updateViewportAndKeyboardProperties);
	}
#endif
}

Theme *Theme::instance()
{
	return g_themeInstance;
}

Victron::VenusOS::Theme::ScreenSize Theme::screenSize() const
{
	return m_screenSize;
}

void Theme::setScreenSize(Victron::VenusOS::Theme::ScreenSize size)
{
	if (m_screenSize != size) {
		setAdjustingGeometry(true);
		m_screenSize = size;

		switch (size) {
		case FiveInch:
			setGeometry_screen_width(800);
			setGeometry_screen_height(480);
			break;
		case SevenInch:
			setGeometry_screen_width(1024);
			setGeometry_screen_height(600);
			break;
		case Portrait:
			setGeometry_screen_width(383);
			setGeometry_screen_height(793);
			break;
		}

		Q_EMIT screenSizeChanged(size);
		Q_EMIT screenSizeChanged_parameterless(); // work around moc limitation.
		setAdjustingGeometry(false);
	}
}

Victron::VenusOS::Theme::ColorScheme Theme::colorScheme() const
{
	return m_colorScheme;
}

void Theme::setColorScheme(Victron::VenusOS::Theme::ColorScheme scheme)
{
	if (m_colorScheme != scheme) {
		m_colorScheme = scheme;
		Q_EMIT colorSchemeChanged(scheme);
		Q_EMIT colorSchemeChanged_parameterless(); // work around moc limitation.
		Q_EMIT partnerThemeChanged();
	}
}

bool Theme::partnerThemeActive() const
{
	return !m_partnerColorOverrides.isEmpty();
}

bool Theme::hasPartnerOverride(const QString &name) const
{
	return m_partnerColorOverrides.contains(name);
}

QColor Theme::partnerColorOverride(const QString &name, const QColor &fallback) const
{
	const auto token = m_partnerColorOverrides.constFind(name);
	if (token == m_partnerColorOverrides.constEnd()) {
		return fallback;
	}
	return token->value(static_cast<int>(m_colorScheme), fallback);
}

bool Theme::applyPartnerTheme(const QVariantMap &definition)
{
	static const QSet<QString> allowedTokens {
		QStringLiteral("color_page_background"),
		QStringLiteral("color_background_secondary"),
		QStringLiteral("color_card_background"),
		QStringLiteral("color_listItem_background"),
		QStringLiteral("color_navigationBar_background"),
		QStringLiteral("color_font_primary"),
		QStringLiteral("color_font_secondary"),
		QStringLiteral("color_listItem_secondaryText"),
		QStringLiteral("color_button"),
		QStringLiteral("color_button_on_background"),
		QStringLiteral("color_blue"),
		QStringLiteral("color_brand_accent"),
		QStringLiteral("color_brand_accent_muted"),
		QStringLiteral("color_droopGraph_gradient_centre"),
		QStringLiteral("color_card_separator"),
		QStringLiteral("color_separator"),
		QStringLiteral("color_listItem_separator"),
		QStringLiteral("color_modalDialog_border"),
		QStringLiteral("color_navigationBar_button_off"),
		QStringLiteral("color_navigationBar_button_on"),
		QStringLiteral("color_overviewPage_widget_battery_background"),
		QStringLiteral("color_overviewPage_widget_background"),
		QStringLiteral("color_overviewPage_widget_border"),
		QStringLiteral("color_overviewPage_widget_solar_graph_bar"),
		QStringLiteral("color_radioButton_indicator_on"),
		QStringLiteral("color_settings_breadcrumb_background_top_page"),
		QStringLiteral("color_focus_highlight"),
		QStringLiteral("color_splash_logo_icon"),
		QStringLiteral("color_splash_logo_text"),
		QStringLiteral("color_darkOk"),
		QStringLiteral("color_ok"),
		QStringLiteral("color_success"),
		QStringLiteral("color_switch_groove_on"),
		QStringLiteral("color_blackWater"),
		QStringLiteral("color_diesel"),
		QStringLiteral("color_freshWater"),
		QStringLiteral("color_fuel"),
		QStringLiteral("color_gasoline"),
		QStringLiteral("color_hydraulicOil"),
		QStringLiteral("color_liveWell"),
		QStringLiteral("color_lng"),
		QStringLiteral("color_lpg"),
		QStringLiteral("color_oil"),
		QStringLiteral("color_rawWater"),
		QStringLiteral("color_wasteWater"),
		QStringLiteral("color_toastNotification_highlight_informative"),
		QStringLiteral("color_warning"),
		QStringLiteral("color_critical")
	};

	QHash<QString, QHash<int, QColor> > candidate;
	auto parseColor = [](const QVariant &value, QColor *result) -> bool {
		if (value.metaType().id() == QMetaType::QColor) {
			*result = value.value<QColor>();
		} else if (value.metaType().id() == QMetaType::QString) {
			*result = QColor(value.toString());
		} else {
			return false;
		}
		return result->isValid();
	};

	for (auto it = definition.constBegin(); it != definition.constEnd(); ++it) {
		if (!allowedTokens.contains(it.key())) {
			qCWarning(venusGui) << "Rejecting partner theme with unsupported token:" << it.key();
			return false;
		}

		QHash<int, QColor> schemes;
		if (it.value().canConvert<QVariantMap>()) {
			const QVariantMap values = it.value().toMap();
			for (auto schemeIt = values.constBegin(); schemeIt != values.constEnd(); ++schemeIt) {
				const int scheme = schemeIt.key().compare(QStringLiteral("dark"), Qt::CaseInsensitive) == 0 ? Dark
						: schemeIt.key().compare(QStringLiteral("light"), Qt::CaseInsensitive) == 0 ? Light
						: -1;
				QColor color;
				if (scheme < 0 || !parseColor(schemeIt.value(), &color)) {
					qCWarning(venusGui) << "Rejecting invalid partner theme value for" << it.key() << schemeIt.key();
					return false;
				}
				schemes.insert(scheme, color);
			}
		} else {
			QColor color;
			if (!parseColor(it.value(), &color)) {
				qCWarning(venusGui) << "Rejecting invalid partner theme value for" << it.key();
				return false;
			}
			schemes.insert(Dark, color);
			schemes.insert(Light, color);
		}
		if (schemes.isEmpty()) {
			qCWarning(venusGui) << "Rejecting empty partner theme value for" << it.key();
			return false;
		}
		candidate.insert(it.key(), schemes);
	}

	if (candidate == m_partnerColorOverrides) {
		return true;
	}
	m_partnerColorOverrides = candidate;
	Q_EMIT partnerThemeChanged();
	return true;
}

void Theme::clearPartnerTheme()
{
	if (!m_partnerColorOverrides.isEmpty()) {
		m_partnerColorOverrides.clear();
		Q_EMIT partnerThemeChanged();
	}
}

Victron::VenusOS::Theme::SystemColorScheme Theme::systemColorScheme() const
{
	return m_systemColorScheme;
}

void Theme::setSystemColorScheme(Victron::VenusOS::Theme::SystemColorScheme systemScheme)
{
	if (m_systemColorScheme != systemScheme) {
		m_systemColorScheme = systemScheme;
		Q_EMIT systemColorSchemeChanged(systemScheme);
		Q_EMIT systemColorSchemeChanged_parameterless(); // work around moc limitation.
	}
}

Victron::VenusOS::Theme::ForcedColorScheme Theme::forcedColorScheme() const
{
	return m_forcedColorScheme;
}

void Theme::setForcedColorScheme(Victron::VenusOS::Theme::ForcedColorScheme forcedScheme)
{
	if (m_forcedColorScheme != forcedScheme) {
		m_forcedColorScheme = forcedScheme;
		Q_EMIT forcedColorSchemeChanged(forcedScheme);

		if (forcedScheme == Victron::VenusOS::Theme::ForcedColorSchemeDark) {
			setColorScheme(Victron::VenusOS::Theme::Dark);
		} else if (forcedScheme == Victron::VenusOS::Theme::ForcedColorSchemeLight) {
			setColorScheme(Victron::VenusOS::Theme::Light);
		} else if (forcedScheme == Victron::VenusOS::Theme::ForcedColorSchemeAuto) {
			// Auto mode: use system color scheme
			setColorScheme(m_systemColorScheme == Victron::VenusOS::Theme::SystemColorSchemeDark
				? Victron::VenusOS::Theme::Dark
				: Victron::VenusOS::Theme::Light);
		}
	}
}

int Theme::geometry_screen_width() const
{
	return m_screenWidth;
}

void Theme::setGeometry_screen_width(int width)
{
	if (m_screenWidth != width) {
		const bool wasAdjusting = adjustingGeometry();
		setAdjustingGeometry(true);
		m_screenWidth = width;
		Q_EMIT geometry_screen_widthChanged();
		setAdjustingGeometry(wasAdjusting);
	}
}

int Theme::geometry_screen_height() const
{
	return m_screenHeight;
}

void Theme::setGeometry_screen_height(int height)
{
	if (m_screenHeight != height) {
		const bool wasAdjusting = adjustingGeometry();
		setAdjustingGeometry(true);
		m_screenHeight = height;
		Q_EMIT geometry_screen_heightChanged();
		setAdjustingGeometry(wasAdjusting);
	}
}

bool Theme::adjustingGeometry() const
{
	return m_adjustingGeometry;
}

void Theme::setAdjustingGeometry(bool adjusting)
{
	if (m_adjustingGeometry != adjusting) {
		m_adjustingGeometry = adjusting;
		Q_EMIT adjustingGeometryChanged();
	}
}

Victron::VenusOS::Theme::StatusLevel Theme::getValueStatus(qreal value, Victron::VenusOS::Enums::Gauges_ValueType valueType) const
{
	if (valueType == Victron::VenusOS::Enums::Gauges_ValueType_RisingPercentage) {
		return value >= 90 ? Critical
			: value >= 80 ? Warning
			: Ok;
	} else if (valueType == Victron::VenusOS::Enums::Gauges_ValueType_FallingPercentage) {
		return value <= 10 ? Critical
			: value <= 20 ? Warning
			: Ok;
	} else {
		return Ok;
	}
}

bool Theme::objectHasQObjectParent(QObject *obj) const
{
	return obj && obj->parent();
}

QString Theme::applicationVersion() const
{
	return QStringLiteral("v%1.%2.%3").arg(PROJECT_VERSION_MAJOR).arg(PROJECT_VERSION_MINOR).arg(PROJECT_VERSION_PATCH);
}

bool Theme::virtualKeyboardOpened() const
{
	return m_virtualKeyboardOpened;
}

int Theme::visualViewportBottom() const
{
	return m_visualViewportBottom;
}

void Theme::updateViewportAndKeyboardProperties()
{
	const int prevViewportBottom = m_visualViewportBottom;
	const bool prevVirtualKeyboardOpened = m_virtualKeyboardOpened;

#if defined(VENUS_WEBASSEMBLY_BUILD)
	// Update the y pos of the bottom of the viewport.
	m_visualViewportBottom = m_visualViewportOffsetTop + m_visualViewportHeight;

	// If the visual viewport is at least 150px shorter than the layout viewport, assume the
	// keyboard is open.
	static const int keyboardMinHeight = 150;
	m_virtualKeyboardOpened = (m_windowHeight - m_visualViewportHeight) > keyboardMinHeight;

#else
	if (QInputMethod *inputMethod = QGuiApplication::inputMethod()) {
		m_virtualKeyboardOpened = inputMethod->isVisible();
		m_visualViewportBottom = inputMethod->keyboardRectangle().y();
	}
#endif

	if (prevViewportBottom != m_visualViewportBottom) {
		Q_EMIT visualViewportBottomChanged();
	}
	if (prevVirtualKeyboardOpened != m_virtualKeyboardOpened) {
		Q_EMIT virtualKeyboardOpenedChanged();
	}
}

void Theme::setVisualViewportOffsetTop(int offsetTop)
{
	if (m_visualViewportOffsetTop != offsetTop) {
		m_visualViewportOffsetTop = offsetTop;
		updateViewportAndKeyboardProperties();
	}
}

void Theme::setVisualViewportHeight(int height)
{
	if (m_visualViewportHeight != height) {
		m_visualViewportHeight = height;
		updateViewportAndKeyboardProperties();
	}
}

void Theme::setWindowHeight(int height)
{
	if (m_windowHeight != height) {
		m_windowHeight = height;
		updateViewportAndKeyboardProperties();
	}
}

#if defined(VENUS_WEBASSEMBLY_BUILD)

// Called from JavaScript when theme changes
void jsSystemColorSchemeChanged(emscripten::val event)
{
	if (!g_themeInstance)
		return;

	const bool systemSchemeDark = event["matches"].as<bool>();
	g_themeInstance->setSystemColorScheme(systemSchemeDark ? Victron::VenusOS::Theme::SystemColorSchemeDark : Victron::VenusOS::Theme::SystemColorSchemeLight);
}

void jsSetWindowInnerHeight(int height)
{
	if (g_themeInstance)
		g_themeInstance->setWindowHeight(height);
}

void jsSetVisualViewportHeight(int height)
{
	if (g_themeInstance)
		g_themeInstance->setVisualViewportHeight(height);
}

void jsSetVisualViewportOffsetTop(int offsetTop)
{
	if (g_themeInstance)
		g_themeInstance->setVisualViewportOffsetTop(offsetTop);
}

// Bind C++ functions to JS — callable as Module.jsSetKeyboardHeight(h) etc.
EMSCRIPTEN_BINDINGS(theme_bindings) {
	using namespace emscripten;
	function("jsSystemColorSchemeChanged", &jsSystemColorSchemeChanged);
	function("jsSetWindowInnerHeight", &jsSetWindowInnerHeight);
	function("jsSetVisualViewportHeight", &jsSetVisualViewportHeight);
	function("jsSetVisualViewportOffsetTop", &jsSetVisualViewportOffsetTop);
}
#endif

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#include "wasmwebviewbridge.h"

#if defined(VENUS_WEBASSEMBLY_BUILD)
#include <emscripten.h>

static WasmWebViewBridge *s_wasmWebViewBridge = nullptr;

extern "C" EMSCRIPTEN_KEEPALIVE void updateWasmWebViewNavigationState(int canGoBack, int canGoForward)
{
	if (s_wasmWebViewBridge)
		s_wasmWebViewBridge->setNavigationState(canGoBack, canGoForward);
}

EM_JS(void, showWasmWebView, (int proxyPort, double x, double y, double width, double height,
	double windowWidth, double windowHeight), {
	const hostname = window.location.hostname.includes(':')
		? '[' + window.location.hostname + ']' : window.location.hostname;
	// Follow the GX local network security profile. GUIv2 is served over HTTP
	// for the Weak and Unsecured profiles and over HTTPS for Secured, so the
	// dedicated web-page origin must use the current page's protocol as well.
	const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
	const source = protocol + '//' + hostname + ':' + proxyPort + '/';
	const expectedOrigin = protocol + '//' + hostname + ':' + proxyPort;
	const wrapper = document.getElementById('wrapper-inner');
	if (!wrapper || !windowWidth || !windowHeight)
		return;

	let frame = document.getElementById('venus-web-content-frame');
	if (!frame) {
		frame = document.createElement('iframe');
		frame.id = 'venus-web-content-frame';
		frame.title = 'Embedded web page';
		frame.setAttribute('sandbox', 'allow-downloads allow-forms allow-modals allow-popups allow-same-origin allow-scripts');
		frame.style.position = 'absolute';
		frame.style.border = '0';
		frame.style.margin = '0';
		frame.style.padding = '0';
		frame.style.background = '#ffffff';
		frame.style.zIndex = '3';
		frame.updateVenusNavigationState = () => {
			try {
				const navigation = frame.contentWindow && frame.contentWindow.navigation;
				Module._updateWasmWebViewNavigationState(
					navigation && navigation.canGoBack ? 1 : 0,
					navigation && navigation.canGoForward ? 1 : 0);
			} catch (error) {
				// Cross-origin frames do not expose their Navigation object. Do not
				// fall back to history.back(): iframe history participates in the
				// top-level joint session history and could navigate GUIv2 itself.
				Module._updateWasmWebViewNavigationState(0, 0);
			}
		};
		frame.addEventListener('load', () => {
			try {
				const navigation = frame.contentWindow && frame.contentWindow.navigation;
				if (navigation && frame.venusNavigation !== navigation) {
					frame.venusNavigation = navigation;
					navigation.addEventListener('currententrychange',
						frame.updateVenusNavigationState);
				}
			} catch (error) {
				// updateVenusNavigationState() will publish the safe disabled state.
			}
			frame.updateVenusNavigationState();
		});
		if (!window.venusWebContentNavigationListenerInstalled) {
			window.addEventListener('message', event => {
				const activeFrame = document.getElementById('venus-web-content-frame');
				if (!activeFrame || event.source !== activeFrame.contentWindow
						|| event.origin !== activeFrame.dataset.expectedOrigin
						|| !event.data || event.data.type !== 'venus-web-pages-navigation')
					return;
				Module._updateWasmWebViewNavigationState(
					event.data.canGoBack ? 1 : 0,
					event.data.canGoForward ? 1 : 0);
			});
			window.venusWebContentNavigationListenerInstalled = true;
		}
		wrapper.appendChild(frame);
	}

	frame.dataset.expectedOrigin = expectedOrigin;
	frame.style.left = (100 * x / windowWidth) + '%';
	frame.style.top = (100 * y / windowHeight) + '%';
	frame.style.width = (100 * width / windowWidth) + '%';
	frame.style.height = (100 * height / windowHeight) + '%';
	frame.style.display = 'block';
	if (frame.getAttribute('src') !== source)
		frame.setAttribute('src', source);
});

EM_JS(void, hideWasmWebView, (), {
	const frame = document.getElementById('venus-web-content-frame');
	if (frame) {
		frame.removeAttribute('src');
		frame.remove();
	}
});

EM_JS(void, reloadWasmWebView, (), {
	const frame = document.getElementById('venus-web-content-frame');
	if (frame && frame.contentWindow)
		frame.contentWindow.postMessage({ type: 'venus-web-pages-navigation', action: 'reload' }, '*');
});

EM_JS(void, goBackWasmWebView, (), {
	const frame = document.getElementById('venus-web-content-frame');
	if (frame && frame.contentWindow)
		frame.contentWindow.postMessage({ type: 'venus-web-pages-navigation', action: 'back' }, '*');
});

EM_JS(void, goForwardWasmWebView, (), {
	const frame = document.getElementById('venus-web-content-frame');
	if (frame && frame.contentWindow)
		frame.contentWindow.postMessage({ type: 'venus-web-pages-navigation', action: 'forward' }, '*');
});
#endif

WasmWebViewBridge::WasmWebViewBridge(QObject *parent)
	: QObject(parent)
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	s_wasmWebViewBridge = this;
#endif
}

void WasmWebViewBridge::show(int proxyPort, qreal x, qreal y, qreal width, qreal height,
	qreal windowWidth, qreal windowHeight)
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	showWasmWebView(proxyPort, x, y, width, height, windowWidth, windowHeight);
#else
	Q_UNUSED(proxyPort)
	Q_UNUSED(x)
	Q_UNUSED(y)
	Q_UNUSED(width)
	Q_UNUSED(height)
	Q_UNUSED(windowWidth)
	Q_UNUSED(windowHeight)
#endif
}

void WasmWebViewBridge::hide()
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	hideWasmWebView();
#endif
	setNavigationState(false, false);
}

void WasmWebViewBridge::reload()
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	reloadWasmWebView();
#endif
}

void WasmWebViewBridge::goBack()
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	goBackWasmWebView();
#endif
}

void WasmWebViewBridge::goForward()
{
#if defined(VENUS_WEBASSEMBLY_BUILD)
	goForwardWasmWebView();
#endif
}

void WasmWebViewBridge::setNavigationState(bool canGoBack, bool canGoForward)
{
	if (m_canGoBack == canGoBack && m_canGoForward == canGoForward)
		return;
	m_canGoBack = canGoBack;
	m_canGoForward = canGoForward;
	emit navigationStateChanged();
}

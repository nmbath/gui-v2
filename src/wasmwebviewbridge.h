/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

#ifndef WASMWEBVIEWBRIDGE_H
#define WASMWEBVIEWBRIDGE_H

#include <QObject>
#include <QString>

class WasmWebViewBridge : public QObject
{
	Q_OBJECT
	Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY navigationStateChanged)
	Q_PROPERTY(bool canGoForward READ canGoForward NOTIFY navigationStateChanged)

public:
	explicit WasmWebViewBridge(QObject *parent = nullptr);
	bool canGoBack() const { return m_canGoBack; }
	bool canGoForward() const { return m_canGoForward; }

	Q_INVOKABLE void show(int proxyPort,
		qreal x, qreal y, qreal width, qreal height,
		qreal windowWidth, qreal windowHeight);
	Q_INVOKABLE void hide();
	Q_INVOKABLE void reload();
	Q_INVOKABLE void goBack();
	Q_INVOKABLE void goForward();
	void setNavigationState(bool canGoBack, bool canGoForward);

signals:
	void navigationStateChanged();

private:
	bool m_canGoBack = false;
	bool m_canGoForward = false;
};

#endif

#ifndef VICTRON_VENUSOS_CLOCKTIME_H
#define VICTRON_VENUSOS_CLOCKTIME_H

#include <QObject>
#include <QDateTime>
#include <QTime>

namespace Victron {

namespace VenusOS {

class ClockTime : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QDateTime currentDateTime MEMBER m_currentDateTime NOTIFY currentDateTimeChanged)
	Q_PROPERTY(QString currentTimeText MEMBER m_currentTimeText NOTIFY currentTimeTextChanged)

public:
	ClockTime(QObject *parent);

	static ClockTime* instance(QObject* parent = nullptr);

signals:
	void currentDateTimeChanged();
	void currentTimeTextChanged();

protected:
	void timerEvent(QTimerEvent *) override;

private:
	void updateTime();
	void scheduleNextTimeCheck(const QTime &now);

	QDateTime m_currentDateTime;
	QString m_currentTimeText;
	int m_timerId = 0;
};

} /* VenusOS */

} /* Victron */

#endif // VICTRON_VENUSOS_CLOCKTIME_H

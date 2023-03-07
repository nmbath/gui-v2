/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import Victron.VenusOS

Page {
	property string bindPrefix

	GradientListView {

		model: ObjectModel {

			ListSwitch {
				id: enableSwitch

				text: CommonWords.enable
				datadataSource: bindPrefix + "/TestRun/Enabled"
			}

			ListSpinBox {
				//% "Run interval"
				text: qsTrId("run_interval")
				dataSource: bindPrefix + "/TestRun/Interval"
				//% "%1 day(s)"
				button.text: qsTrId("page_generator_test_run_days").arg(value)
				stepSize: 1
				from: 1
				to: 30
			}

			ListRadioButtonGroup {
				//% "Skip run if has been running for"
				text: qsTrId("page_generator_test_run_skip_run")
				dataSource: bindPrefix + "/TestRun/SkipRuntime"
				optionModel: [
					//% "Start always"
					{ display: qsTrId("page_generator_test_run_start_always"), value: 0 },
					{ display: CommonWords.x_hours.arg(1), value: 3600 },
					{ display: CommonWords.x_hours.arg(2), value: 7200 },
					{ display: CommonWords.x_hours.arg(4), value: 14400 },
					{ display: CommonWords.x_hours.arg(6), value: 21600 },
					{ display: CommonWords.x_hours.arg(8), value: 28800 },
					{ display: CommonWords.x_hours.arg(10), value: 36000 },
				]
			}

			ListDateSelector {
				//% "Run interval start date"
				text: qsTrId("page_generator_test_run_run_interval_start_date")
				dataSource: bindPrefix + "/TestRun/StartDate"
			}

			ListTimeSelector {
				text: CommonWords.start_time
				dataSource: bindPrefix + "/TestRun/StartTime"
			}

			ListTimeSelector {
				//% "Run duration (hh:mm)"
				text: qsTrId("page_generator_test_run_run_duration")
				dataSource: bindPrefix + "/TestRun/Duration"
				visible: !runTillBatteryFull.checked
			}

			ListSwitch {
				id: runTillBatteryFull

				//% "Run until battery is fully charged"
				text: qsTrId("page_generator_test_run_run_until_fully_charged")
				dataSource: bindPrefix + "/TestRun/RunTillBatteryFull"
				visible: dataValid
			}
		}
	}
}

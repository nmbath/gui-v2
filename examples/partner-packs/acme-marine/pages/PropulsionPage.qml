import QtQuick
import Victron.VenusOS

SwipeViewPage {
    id: root

    Rectangle {
        anchors.fill: parent
        color: Theme.color_page_background

        Column {
            anchors.centerIn: parent
            spacing: 16

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Acme Marine"
                font.pixelSize: 32
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Propulsion partner page"
            }
        }
    }
}

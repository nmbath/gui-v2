import QtQuick
import Victron.VenusOS

Page {
    title: "Acme Marine"

    SettingsColumn {
        ListText {
            text: "Partner pack"
            secondaryText: PartnerBrand.displayName + " " + PartnerBrand.version
        }
    }
}

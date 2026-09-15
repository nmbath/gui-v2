set(VictronPartnerSdk_QML_MODULE_SOURCES
    partner-sdk/PartnerMappedMetric.qml
    partner-sdk/PartnerNavigationPage.qml
    partner-sdk/PartnerStyle.qml
)

set_source_files_properties(
    partner-sdk/PartnerMappedMetric.qml
    PROPERTIES QT_RESOURCE_ALIAS PartnerMappedMetric.qml
)

set_source_files_properties(
    partner-sdk/PartnerNavigationPage.qml
    PROPERTIES QT_RESOURCE_ALIAS PartnerNavigationPage.qml
)

set_source_files_properties(
    partner-sdk/PartnerStyle.qml
    PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
        QT_RESOURCE_ALIAS PartnerStyle.qml
)

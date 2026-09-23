qt_add_library(VictronPartnerSdk STATIC)
qt_add_qml_module(VictronPartnerSdk
    URI Victron.PartnerSdk
    VERSION 1.0
    OUTPUT_DIRECTORY Victron/PartnerSdk
    QML_FILES ${VictronPartnerSdk_QML_MODULE_SOURCES}
    ${QML_MODULE_OPTARGS}
)

target_link_libraries(VictronPartnerSdk PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

if (${VENUS_GX_BUILD})
    qt_query_qml_module(VictronPartnerSdk QML_FILES module_qml_files QMLDIR module_qmldir)
    install(DIRECTORY partner-sdk/ DESTINATION ${CMAKE_INSTALL_BINDIR}/Victron/PartnerSdk)
    install(FILES ${module_qmldir} DESTINATION ${CMAKE_INSTALL_BINDIR}/Victron/PartnerSdk)
endif()

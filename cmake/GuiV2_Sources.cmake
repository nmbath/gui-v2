set(GUIV2_QML_SOURCES
    Main.qml
)

set(GUIV2_CPP_SOURCES
    src/main.cpp
    src/wasmwebviewbridge.cpp
    src/wasmwebviewbridge.h
)

set_source_files_properties(
    ${GUIV2_CPP_SOURCES}
    PROPERTIES
    COMPILE_OPTIONS "${venusCompileFlags}"
)

list(APPEND SOURCES ${GUIV2_CPP_SOURCES})

cmake_minimum_required(VERSION 3.25)
project(Aetheria VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(MSVC)
    add_compile_options("$<$<CONFIG:Release>:/O2;/Oi;/Gy>")
    add_link_options("$<$<CONFIG:Release>:/OPT:REF;/OPT:ICF>")
else()
    add_compile_options("$<$<CONFIG:Release>:-O3;-fomit-frame-pointer>")
    add_link_options("$<$<CONFIG:Release>:-s>")
endif()

find_package(Qt6 REQUIRED COMPONENTS
        Core
        Gui
        Qml
        Quick
        QuickControls2
        QuickEffects
        Multimedia
        Network
        Sql
        Concurrent
)

qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)
qt_standard_project_setup()

set(PROJECT_SOURCES
        src/main.cpp
        src/core/AudioEngine.h
        src/core/AudioEngine.cpp
        src/core/TrackModel.h
        src/core/TrackModel.cpp
        src/core/SleepTimer.h
        src/core/SleepTimer.cpp
        src/core/EqualizerModel.h
        src/core/EqualizerModel.cpp
        src/core/GlobalMediaKeyFilter.h
        src/database/DatabaseManager.h
        src/database/DatabaseManager.cpp
        src/network/LyricsService.h
        src/network/LyricsService.cpp
        src/network/DownloadManager.h
        src/network/DownloadManager.cpp
        src/network/OnlineSearchEngine.h
        src/network/OnlineSearchEngine.cpp
        app.rc
)

add_executable(Aetheria WIN32 ${PROJECT_SOURCES})


qt_add_qml_module(Aetheria
        URI MusicPlayerApp
        VERSION 1.0
        QML_FILES
        ui/qml/Main.qml
        ui/qml/MiniPlayerWindow.qml
        ui/qml/views/StageView.qml
        ui/qml/views/LyricsView.qml
        ui/qml/views/DiscoverView.qml
        ui/qml/components/EqualizerPanel.qml
        RESOURCES
        assets/logo1.png
        assets/app_icon.ico
        assets/idle_bg.png
)

target_link_libraries(Aetheria PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::QuickEffects
        Qt6::Multimedia
        Qt6::Network
        Qt6::Sql
        Qt6::Concurrent
        dwmapi
)

target_include_directories(Aetheria PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/core
        ${CMAKE_CURRENT_SOURCE_DIR}/src/database
        ${CMAKE_CURRENT_SOURCE_DIR}/src/network
)

if(WIN32)
    get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")

    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET Aetheria POST_BUILD
                COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/ui/qml"
                $<$<CONFIG:Release>:--release>
                $<$<CONFIG:Debug>:--debug>
                --no-translations
                --compiler-runtime
                --plugindir "$<TARGET_FILE_DIR:Aetheria>/plugins"
                "$<TARGET_FILE:Aetheria>"
                COMMENT "Deploying Qt dependencies and QML modules using windeployqt..."
        )
    endif()

    if(MINGW)
        get_filename_component(MINGW_BIN_DIR ${CMAKE_CXX_COMPILER} DIRECTORY)
        add_custom_command(TARGET Aetheria POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MINGW_BIN_DIR}/libwinpthread-1.dll"
                "$<TARGET_FILE_DIR:Aetheria>"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MINGW_BIN_DIR}/libgcc_s_seh-1.dll"
                "$<TARGET_FILE_DIR:Aetheria>"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MINGW_BIN_DIR}/libstdc++-6.dll"
                "$<TARGET_FILE_DIR:Aetheria>"
                COMMENT "Copying MinGW runtime DLLs to output directory..."
        )
    endif()

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/yt-dlp.exe")
        add_custom_command(TARGET Aetheria POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/yt-dlp.exe"
                "$<TARGET_FILE_DIR:Aetheria>"
                COMMENT "Copying yt-dlp.exe to output directory..."
        )
    endif()
endif()
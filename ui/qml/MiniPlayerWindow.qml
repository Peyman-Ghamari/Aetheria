import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import MusicPlayer.Core 1.0

Window {
    id: miniRoot
    width: 340
    height: 96

    // قفل ابعاد جهت جلوگیری از کلمپ و مچاله شدن هنگام جابه‌جایی بین مانیتورها
    minimumWidth: 340
    maximumWidth: 340
    minimumHeight: 96
    maximumHeight: 96

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    visible: false

    property string trackTitle: ""
    property string trackArtist: ""
    property string trackCover: ""

    property bool hasCustomPosition: false

    signal restoreRequested()

    function openMiniPlayer() {
        var targetScreen = miniRoot.screen ? miniRoot.screen : Screen
        var vX = targetScreen.virtualX ? targetScreen.virtualX : 0
        var vY = targetScreen.virtualY ? targetScreen.virtualY : 0
        var sW = targetScreen.desktopAvailableWidth ? targetScreen.desktopAvailableWidth : targetScreen.width
        var sH = targetScreen.desktopAvailableHeight ? targetScreen.desktopAvailableHeight : targetScreen.height

        if (!hasCustomPosition) {
            x = vX + sW - width - 16
            y = vY + sH - height - 16
            hasCustomPosition = true
        }

        show()
        raise()
        requestActivate()
    }

    Rectangle {
        id: container
        anchors.fill: parent
        radius: 16
        color: "#120a21"
        border.color: "#8b5cf6"
        border.width: 1.2
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    miniRoot.startSystemMove()
                    miniRoot.hasCustomPosition = true
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62
                radius: 12
                color: "#1d1136"
                border.color: "#351c5e"
                border.width: 1
                clip: true

                Image {
                    id: miniCoverImg
                    anchors.fill: parent
                    source: (miniRoot.trackCover && miniRoot.trackCover !== "") ? miniRoot.trackCover : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: miniRoot.trackCover !== "" && status === Image.Ready
                }

                Image {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: "qrc:/qt/qml/MusicPlayerApp/assets/logo1.png"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    smooth: true
                    mipmap: true
                    visible: !miniCoverImg.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    text: (miniRoot.trackTitle && miniRoot.trackTitle !== "") ? miniRoot.trackTitle : "No Active Stream"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: (miniRoot.trackArtist && miniRoot.trackArtist !== "") ? miniRoot.trackArtist : "Idle"
                    color: "#c084fc"
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: 1.5
                    color: "#25173d"

                    Rectangle {
                        height: parent.height
                        width: AudioEngine.duration > 0 ? (AudioEngine.position / AudioEngine.duration) * parent.width : 0
                        radius: 1.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#8b5cf6" }
                            GradientStop { position: 1.0; color: "#ec4899" }
                        }
                    }
                }
            }

            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Rectangle {
                    id: prevBtnBox
                    width: 30
                    height: 30
                    radius: 15
                    color: prevMouse.containsMouse ? "#261545" : "transparent"
                    border.color: prevMouse.containsMouse ? "#a855f7" : "transparent"
                    border.width: 1

                    Shape {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        ShapePath {
                            strokeWidth: 0
                            fillColor: prevMouse.containsMouse ? "#ffffff" : "#c084fc"
                            startX: 0; startY: 1
                            PathLine { x: 2; y: 1 }
                            PathLine { x: 2; y: 11 }
                            PathLine { x: 0; y: 11 }
                            PathLine { x: 0; y: 1 }
                        }
                        ShapePath {
                            strokeWidth: 0
                            fillColor: prevMouse.containsMouse ? "#ffffff" : "#c084fc"
                            startX: 12; startY: 1
                            PathLine { x: 2.5; y: 6 }
                            PathLine { x: 12; y: 11 }
                            PathLine { x: 12; y: 1 }
                        }
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TrackModel.playPrevious()
                    }
                }

                Rectangle {
                    id: playBtnBox
                    width: 38
                    height: 38
                    radius: 19
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: playMouse.pressed ? "#6d28d9" : "#7c3aed" }
                        GradientStop { position: 1.0; color: playMouse.pressed ? "#db2777" : "#ec4899" }
                    }
                    scale: playMouse.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    Shape {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.2
                        width: 12
                        height: 14
                        visible: !AudioEngine.isPlaying
                        ShapePath {
                            strokeWidth: 0
                            fillColor: "#ffffff"
                            startX: 1; startY: 1
                            PathLine { x: 11; y: 7 }
                            PathLine { x: 1; y: 13 }
                            PathLine { x: 1; y: 1 }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        visible: AudioEngine.isPlaying

                        Rectangle { width: 3; height: 12; radius: 1.5; color: "#ffffff" }
                        Rectangle { width: 3; height: 12; radius: 1.5; color: "#ffffff" }
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioEngine.togglePlayPause()
                    }
                }

                // دکمه Next
                Rectangle {
                    id: nextBtnBox
                    width: 30
                    height: 30
                    radius: 15
                    color: nextMouse.containsMouse ? "#261545" : "transparent"
                    border.color: nextMouse.containsMouse ? "#a855f7" : "transparent"
                    border.width: 1

                    Shape {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        ShapePath {
                            strokeWidth: 0
                            fillColor: nextMouse.containsMouse ? "#ffffff" : "#c084fc"
                            startX: 0; startY: 1
                            PathLine { x: 9.5; y: 6 }
                            PathLine { x: 0; y: 11 }
                            PathLine { x: 0; y: 1 }
                        }
                        ShapePath {
                            strokeWidth: 0
                            fillColor: nextMouse.containsMouse ? "#ffffff" : "#c084fc"
                            startX: 10; startY: 1
                            PathLine { x: 12; y: 1 }
                            PathLine { x: 12; y: 11 }
                            PathLine { x: 10; y: 11 }
                            PathLine { x: 10; y: 1 }
                        }
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TrackModel.playNextTrack(AudioEngine.isShuffle)
                    }
                }

                Rectangle {
                    id: restoreBtnBox
                    width: 28
                    height: 28
                    radius: 14
                    color: restoreMa.containsMouse ? "#3b1130" : "#1a102b"
                    border.color: restoreMa.containsMouse ? "#ec4899" : "#3b2061"
                    border.width: 1

                    Shape {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        smooth: true
                        antialiasing: true

                        ShapePath {
                            strokeWidth: 1.5
                            strokeColor: restoreMa.containsMouse ? "#f472b6" : "#c084fc"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 1; startY: 5
                            PathLine { x: 1; y: 1 }
                            PathLine { x: 5; y: 1 }
                        }
                        ShapePath {
                            strokeWidth: 1.5
                            strokeColor: restoreMa.containsMouse ? "#f472b6" : "#c084fc"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 1; startY: 1
                            PathLine { x: 6; y: 6 }
                        }
                        ShapePath {
                            strokeWidth: 1.5
                            strokeColor: restoreMa.containsMouse ? "#f472b6" : "#c084fc"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 11; startY: 7
                            PathLine { x: 11; y: 11 }
                            PathLine { x: 7; y: 11 }
                        }
                        ShapePath {
                            strokeWidth: 1.5
                            strokeColor: restoreMa.containsMouse ? "#f472b6" : "#c084fc"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 11; startY: 11
                            PathLine { x: 6; y: 6 }
                        }
                    }

                    MouseArea {
                        id: restoreMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: miniRoot.restoreRequested()
                    }

                    ToolTip.visible: restoreMa.containsMouse
                    ToolTip.text: "Restore Full Suite"
                    ToolTip.delay: 300
                }
            }
        }
    }
}
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MusicPlayer.Core 1.0

Rectangle {
    id: panelRoot
    implicitWidth: 620
    implicitHeight: 380
    width: implicitWidth
    height: implicitHeight

    radius: 20
    color: "#160b24"
    border.color: "#ec4899"
    border.width: 1
    opacity: 0.96

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16


        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "10-BAND EQUALIZER"
                color: "#f472b6"
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 1.5
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Reset"
                flat: true
                contentItem: Text {
                    text: parent.text
                    color: "#a78bfa"
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? "#2e1065" : "#1e1136"
                    radius: 8
                    border.color: "#7c3aed"
                }
                onClicked: EqualizerModel.resetToFlat()
            }

            ComboBox {
                id: presetCombo
                model: EqualizerModel.availablePresets
                currentIndex: model.indexOf(EqualizerModel.currentPreset)
                implicitWidth: 130
                implicitHeight: 32

                background: Rectangle {
                    color: "#1e1136"
                    radius: 8
                    border.color: "#ec4899"
                }

                contentItem: Text {
                    text: presetCombo.displayText
                    color: "#fdf2f8"
                    font.pixelSize: 12
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }

                onActivated: function(index) {
                    EqualizerModel.currentPreset = textAt(index)
                }
            }

            Switch {
                id: eqSwitch
                checked: EqualizerModel.isEnabled
                onToggled: EqualizerModel.isEnabled = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            opacity: EqualizerModel.isEnabled ? 1.0 : 0.35

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: 10

                delegate: ColumnLayout {
                    id: colDelegate
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    Text {
                        text: {
                            var g = EqualizerModel.getBandGain(colDelegate.index)
                            return (g > 0 ? "+" : "") + g.toFixed(1)
                        }
                        color: colDelegate.index % 2 === 0 ? "#f472b6" : "#a78bfa"
                        font.pixelSize: 10
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Slider {
                        id: bandSlider
                        orientation: Qt.Vertical
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        from: -12.0
                        to: 12.0
                        stepSize: 0.5
                        value: EqualizerModel.getBandGain(colDelegate.index)
                        enabled: EqualizerModel.isEnabled

                        onMoved: {
                            EqualizerModel.setBandGain(colDelegate.index, bandSlider.value)
                        }

                        Connections {
                            target: EqualizerModel
                            function onBandGainsChanged() {
                                bandSlider.value = EqualizerModel.getBandGain(colDelegate.index)
                            }
                        }
                    }

                    Text {
                        text: EqualizerModel.bandLabels[colDelegate.index]
                        color: "#94a3b8"
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
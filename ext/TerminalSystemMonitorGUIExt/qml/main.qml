import QtQuick 2.15
import QtQuick.Controls 2.15
import org.julialang

ApplicationWindow {
    id: mainWindow
    title: "Terminal System Monitor"
    visible: true
    width: 600
    height: 260
    palette.window: "#f0f0f0"
    color: "#f0f0f0" // bgcolor

    property real cpuPercent: 0
    property real memoryUsed: 0

    Timer {
        id: updateTimer
        interval: 1000 // 1s
        repeat: true
        running: true
        onTriggered: {
            cpuPercent = Julia.get_mean_cpu_percent()
            memoryUsed = Julia.get_memory_used()
        }
    }

    Item {
        id: rootContainer
        anchors.fill: parent

        Rectangle {
            id: topBar
            x: 10
            y: 10
            width: parent.width - 20
            height: 50
            radius: 5
            color: "#1e88e5"

            Row {
                id: topRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 20

                Label {
                    text: "Terminal System Monitor"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }

                Item {
                    width: parent.width - 300
                }

                Label {
                    text: "Uptime: " + system_data.uptime
                    font.pixelSize: 14
                    color: "white"
                }

                Label {
                    text: {
                        var loadAvg = system_data.loadAverage;
                        return "Load: " + loadAvg[0].toFixed(2) + " " +
                               loadAvg[1].toFixed(2) + " " +
                               loadAvg[2].toFixed(2);
                    }
                    font.pixelSize: 14
                    color: "white"
                }
            }
        }

        // bottom bar
        Rectangle {
            id: bottomBar
            x: 10
            width: parent.width - 20
            height: 30
            radius: 5
            color: "#f5f5f5"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10

            Row {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10

                Label {
                    font.pixelSize: 12
                    text: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: {
                            parent.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
                        }
                    }
                }
            }
        }

        ScrollView {
            id: mainScroll
            x: 10
            y: topBar.y + topBar.height + 10
            width: parent.width - 20
            height: bottomBar.y - (topBar.y + topBar.height) - 20

            clip: true

            Column {
                id: contentColumn
                spacing: 10
                width: parent.width // ScrollView's contentWidth

                GroupBox {
                    title: "Average CPU usage"
                    width: parent.width

                    Row {
                        spacing: 10
                        width: parent.width

                        ProgressBar {
                            from: 0
                            to: 100
                            value: cpuPercent
                            // Give an approximate width, leaving room for Label on the right.
                            width: parent.width - 100
                        }

                        Label {
                            text: (cpuPercent/100).toFixed(2) + "%"
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                GroupBox {
                    title: "Memory usage"
                    width: parent.width

                    Row {
                        spacing: 10
                        width: parent.width

                        ProgressBar {
                            from: 0
                            to: system_data.memoryTotal
                            value: memoryUsed
                            width: parent.width - 100
                        }

                        Label {
                            text: memoryUsed.toFixed(1) + " / " +
                                  system_data.memoryTotal.toFixed(1) + " " +
                                  system_data.memoryUnit
                        }
                    }
                }
            }
        }
    }
}
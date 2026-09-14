#pragma once

#include <QObject>
#include <QAbstractNativeEventFilter>
#include <QByteArray>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

class GlobalMediaKeyFilter : public QObject, public QAbstractNativeEventFilter {
    Q_OBJECT

public:
    enum HotKeyId {
        HK_PLAY_PAUSE = 9001,
        HK_NEXT,
        HK_PREV,
        HK_TOGGLE_MINIPLAYER
    };

    explicit GlobalMediaKeyFilter(QObject *parent = nullptr)
        : QObject(parent) {
#ifdef Q_OS_WIN
        registerGlobalHotKeys();
#endif
    }

    ~GlobalMediaKeyFilter() override {
#ifdef Q_OS_WIN
        unregisterGlobalHotKeys();
#endif
    }

signals:
    void playPauseTriggered();
    void nextTriggered();
    void previousTriggered();
    void toggleMiniPlayerTriggered();

private:
#ifdef Q_OS_WIN
    void registerGlobalHotKeys() {
        RegisterHotKey(NULL, HK_PLAY_PAUSE, 0, VK_MEDIA_PLAY_PAUSE);
        RegisterHotKey(NULL, HK_NEXT, 0, VK_MEDIA_NEXT_TRACK);
        RegisterHotKey(NULL, HK_PREV, 0, VK_MEDIA_PREV_TRACK);


        BOOL ok = RegisterHotKey(NULL, HK_TOGGLE_MINIPLAYER, MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, 'M');
        if (!ok) {

            ok = RegisterHotKey(NULL, HK_TOGGLE_MINIPLAYER, MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, 'M');
        }
        qDebug() << "[GlobalHotKey] MiniPlayer Shortcut registered successfully:" << (ok ? "YES" : "NO (Error code: " + QString::number(GetLastError()) + ")");
    }

    void unregisterGlobalHotKeys() {
        UnregisterHotKey(NULL, HK_PLAY_PAUSE);
        UnregisterHotKey(NULL, HK_NEXT);
        UnregisterHotKey(NULL, HK_PREV);
        UnregisterHotKey(NULL, HK_TOGGLE_MINIPLAYER);
    }
#endif

protected:
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override {
#ifdef Q_OS_WIN
        auto *msg = static_cast<MSG *>(message);

        if (msg->message == WM_HOTKEY) {
            int id = static_cast<int>(msg->wParam);
            if (id == HK_TOGGLE_MINIPLAYER) {
                qDebug() << "[GlobalHotKey] MiniPlayer Hotkey pressed!";
                emit toggleMiniPlayerTriggered();
                if (result) *result = 1;
                return true;
            } else if (id == HK_PLAY_PAUSE) {
                emit playPauseTriggered();
                if (result) *result = 1;
                return true;
            } else if (id == HK_NEXT) {
                emit nextTriggered();
                if (result) *result = 1;
                return true;
            } else if (id == HK_PREV) {
                emit previousTriggered();
                if (result) *result = 1;
                return true;
            }
        }

        if (msg->message == WM_APPCOMMAND) {
            int cmd = GET_APPCOMMAND_LPARAM(msg->lParam);
            switch (cmd) {
            case APPCOMMAND_MEDIA_PLAY_PAUSE:
            case APPCOMMAND_MEDIA_PLAY:
            case APPCOMMAND_MEDIA_PAUSE:
                emit playPauseTriggered();
                if (result) *result = 1;
                return true;
            case APPCOMMAND_MEDIA_NEXTTRACK:
                emit nextTriggered();
                if (result) *result = 1;
                return true;
            case APPCOMMAND_MEDIA_PREVIOUSTRACK:
                emit previousTriggered();
                if (result) *result = 1;
                return true;
            default:
                break;
            }
        }
#else
        Q_UNUSED(eventType);
        Q_UNUSED(message);
        Q_UNUSED(result);
#endif
        return false;
    }
};
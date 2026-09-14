#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QStringList>
#include <QVariantList>

class DatabaseManager : public QObject {
    Q_OBJECT
public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager() override = default;

    bool initDatabase();

    // Playlists
    Q_INVOKABLE bool createPlaylist(const QString &name);
    Q_INVOKABLE bool deletePlaylist(const QString &name);
    Q_INVOKABLE QStringList getPlaylists();
    Q_INVOKABLE bool addTrackToPlaylist(const QString &playlistName, const QString &filePath);
    Q_INVOKABLE bool addTracksToPlaylist(const QString &playlistName, const QStringList &filePaths);
    Q_INVOKABLE bool removeTrackFromPlaylist(const QString &playlistName, const QString &filePath);
    Q_INVOKABLE QStringList getPlaylistTracks(const QString &playlistName);

    // Track state (Liked)
    Q_INVOKABLE bool setTrackLiked(const QString &filePath, bool liked);
    Q_INVOKABLE bool isTrackLiked(const QString &filePath);
    Q_INVOKABLE QStringList getLikedTracks();

private:
    QSqlDatabase m_db;
};
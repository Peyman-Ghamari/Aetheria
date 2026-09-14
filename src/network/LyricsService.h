#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QList>
#include <QString>

struct LyricLine {
    qint64 timestampMs;
    QString text;
};

class LyricsService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasSyncedLyrics READ hasSyncedLyrics NOTIFY hasSyncedLyricsChanged)
    Q_PROPERTY(int linesCount READ getLinesCount NOTIFY linesCountChanged)
    Q_PROPERTY(QString rawLyrics READ rawLyrics NOTIFY rawLyricsChanged)
    Q_PROPERTY(int currentLineIndex READ currentLineIndex NOTIFY currentLineIndexChanged)

public:
    explicit LyricsService(QObject *parent = nullptr);
    ~LyricsService() override = default;

    bool isLoading() const;
    bool hasSyncedLyrics() const;
    QString rawLyrics() const;
    int currentLineIndex() const;

    Q_INVOKABLE int getLinesCount() const;
    Q_INVOKABLE QString getLineText(int index) const;
    Q_INVOKABLE qint64 getLineTime(int index) const;

public slots:
    void fetchLyrics(const QString &title, const QString &artist, const QString &filePath = "");
    void updatePosition(qint64 positionMs);
    void clear();

signals:
    void loadingChanged(bool loading);
    void hasSyncedLyricsChanged(bool hasSynced);
    void linesCountChanged(int count);
    void rawLyricsChanged(const QString &lyrics);
    void currentLineIndexChanged(int index);

private slots:
    void onMusixmatchTokenFinished();
    void onMusixmatchSubtitlesFinished();
    void onLrclibDirectFinished();
    void onLrclibFuzzyFinished();
    void onNetEaseSearchFinished();
    void onNetEaseLyricsFinished();
    void onGeniusMultiSearchFinished();
    void onGeniusHtmlPageFinished();
    void onDuckDuckGoSearchFinished();
    void onGenericWebPageFinished();

private:
    void parseLrc(const QString &lrcContent);
    void parseMusixmatchSubtitlesJson(const QString &jsonSubtitles);
    bool extractEmbeddedLyrics(const QString &filePath);
    QString sanitizeQuery(const QString &input);
    QString cleanHtmlLyrics(const QString &html);

    void getMusixmatchTokenThenFetch();
    void step1_FetchMusixmatch();
    void step2_FetchLrclibExact();
    void step3_FetchLrclibFuzzy();
    void step4_FetchNetEase();
    void step5_FetchGenius();
    void step6_FetchPersianWeb();

    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply = nullptr;

    QString m_musixmatchToken;
    QString m_targetTitle;
    QString m_targetArtist;
    QString m_currentFilePath;

    QList<LyricLine> m_lines;
    QString m_rawLyrics;
    bool m_isLoading = false;
    bool m_hasSynced = false;
    int m_currentLineIndex = -1;
};
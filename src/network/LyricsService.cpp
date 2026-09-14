#include "LyricsService.h"
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>
#include <QUrl>
#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QDebug>
#include <QSqlDatabase>
#include <QSqlQuery>

static const QString MXM_APP_ID = "web-desktop-app-v1.0";
static const QString BROWSER_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

LyricsService::LyricsService(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this)) {
    QSettings settings("Aetheria", "MusicPlayer");
    m_musixmatchToken = settings.value("musixmatch_token", "").toString();
}

bool LyricsService::isLoading() const { return m_isLoading; }
bool LyricsService::hasSyncedLyrics() const { return m_hasSynced; }
QString LyricsService::rawLyrics() const { return m_rawLyrics; }
int LyricsService::currentLineIndex() const { return m_currentLineIndex; }

int LyricsService::getLinesCount() const {
    return static_cast<int>(m_lines.size());
}

QString LyricsService::getLineText(int index) const {
    if (index >= 0 && index < m_lines.size()) {
        return m_lines.at(index).text;
    }
    return QString();
}

qint64 LyricsService::getLineTime(int index) const {
    if (index >= 0 && index < m_lines.size()) {
        return m_lines.at(index).timestampMs;
    }
    return 0;
}

void LyricsService::clear() {
    if (m_currentReply) {
        m_currentReply->disconnect();
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    m_lines.clear();
    m_lines.squeeze();

    m_rawLyrics.clear();
    m_rawLyrics.squeeze();

    m_hasSynced = false;
    m_currentLineIndex = -1;

    emit hasSyncedLyricsChanged(false);
    emit linesCountChanged(0);
    emit rawLyricsChanged("");
    emit currentLineIndexChanged(-1);
}

QString LyricsService::sanitizeQuery(const QString &input) {
    static const QRegularExpression mentionRx("@[a-zA-Z0-9_]+", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression qualityRx("\\(320\\)|\\(128\\)|\\[320\\]|\\[128\\]", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression noiseRx("\\b(official|audio|video|remix|explicit|single)\\b", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression symbolsRx("[\\[\\]\\(\\)\\{\\}_\\-\\+]");

    QString res = input;
    res.remove(mentionRx);
    res.remove(qualityRx);
    res.remove(noiseRx);
    res.replace("&", " ");
    res.remove(symbolsRx);
    return res.simplified().trimmed();
}

QString LyricsService::cleanHtmlLyrics(const QString &html) {
    static const QRegularExpression brRx("<br\\s*/?>", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression pRx("</p>", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression divRx("</div>", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression scriptRx("<script[^>]*>.*?</script>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression styleRx("<style[^>]*>.*?</style>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression tagRx("<[^>]*>");


    static const QRegularExpression contribRx("^[0-9]+\\s*Contributors?.*?\n", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression geniusHeaderRx("^[0-9]+\\s*Contributors?.*?Lyrics", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression youMightRx("You might also like.*", QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression embedRx("[0-9]*Embed$", QRegularExpression::CaseInsensitiveOption);


    static const QRegularExpression titleBracketRx("^\\[متن آهنگ[^\\]]*\\]\\s*", QRegularExpression::CaseInsensitiveOption);

    QString text = html;
    text.replace(brRx, "\n");
    text.replace(pRx, "\n\n");
    text.replace(divRx, "\n");
    text.remove(scriptRx);
    text.remove(styleRx);
    text.remove(tagRx);

    text.replace("&quot;", "\"");
    text.replace("&amp;", "&");
    text.replace("&#x27;", "'");
    text.replace("&#39;", "'");
    text.replace("&apos;", "'");
    text.replace("&lt;", "<");
    text.replace("&gt;", ">");
    text.replace("&nbsp;", " ");

    text.remove(contribRx);
    text.remove(geniusHeaderRx);
    text.remove(youMightRx);
    text.remove(embedRx);
    text = text.trimmed();

    text.remove(titleBracketRx);

    return text.trimmed();
}

bool LyricsService::extractEmbeddedLyrics(const QString &filePath) {
    if (filePath.isEmpty()) return false;

    QString cleanPath = filePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    cleanPath = QDir::fromNativeSeparators(cleanPath);

    QFileInfo fi(cleanPath);
    QDir dir = fi.dir();
    QString baseName = fi.completeBaseName();

    QStringList localLrcCandidates;
    localLrcCandidates << dir.filePath(baseName + ".lrc")
                       << dir.filePath(baseName + ".txt")
                       << dir.filePath("lyrics.lrc")
                       << dir.filePath("lyrics.txt");

    for (const QString &lrcPath : localLrcCandidates) {
        if (QFile::exists(lrcPath)) {
            QFile lrcFile(lrcPath);
            if (lrcFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QString content = QString::fromUtf8(lrcFile.readAll()).trimmed();
                lrcFile.close();
                if (!content.isEmpty()) {
                    if (content.contains("[00:") || content.contains("[01:")) {
                        parseLrc(content);
                    } else {
                        m_rawLyrics = content;
                        m_hasSynced = false;
                        m_isLoading = false;
                        emit rawLyricsChanged(m_rawLyrics);
                        emit linesCountChanged(0);
                        emit hasSyncedLyricsChanged(false);
                        emit loadingChanged(false);
                    }
                    return true;
                }
            }
        }
    }

    return false;
}

void LyricsService::fetchLyrics(const QString &title, const QString &artist, const QString &filePath) {
    clear();

    m_currentFilePath = filePath;
    m_targetTitle = sanitizeQuery(title);
    m_targetArtist = (artist == "Local Artist" || artist == "Official Track" || artist == "Idle") ? "" : sanitizeQuery(artist);


    if (!filePath.isEmpty() && QSqlDatabase::contains("PMPlayerConnection")) {
        QSqlDatabase db = QSqlDatabase::database("PMPlayerConnection");
        if (db.isOpen()) {
            QSqlQuery q(db);
            q.prepare("SELECT synced_lyrics FROM tracks WHERE file_path = :path LIMIT 1");
            q.bindValue(":path", filePath);
            if (q.exec() && q.next()) {
                QString cachedLrc = q.value(0).toString().trimmed();
                if (!cachedLrc.isEmpty()) {
                    parseLrc(cachedLrc);
                    return;
                }
            }
        }
    }


    if (!filePath.isEmpty() && extractEmbeddedLyrics(filePath)) {
        return;
    }

    m_isLoading = true;
    emit loadingChanged(true);

    step2_FetchLrclibExact();
}

void LyricsService::step2_FetchLrclibExact() {
    QUrl url("https://lrclib.net/api/get");
    QUrlQuery q;
    q.addQueryItem("track_name", m_targetTitle);
    if (!m_targetArtist.isEmpty()) {
        q.addQueryItem("artist_name", m_targetArtist);
    }
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "AetheriaMusicSuite/5.0");
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onLrclibDirectFinished);
}

void LyricsService::onLrclibDirectFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject obj = QJsonDocument::fromJson(data).object();
        QString syncedLyrics = obj.value("syncedLyrics").toString().trimmed();
        QString plainLyrics = obj.value("plainLyrics").toString().trimmed();

        if (!syncedLyrics.isEmpty()) {
            parseLrc(syncedLyrics);
            reply->deleteLater();
            return;
        } else if (!plainLyrics.isEmpty()) {
            m_rawLyrics = plainLyrics;
            m_hasSynced = false;
            m_isLoading = false;
            emit rawLyricsChanged(m_rawLyrics);
            emit linesCountChanged(0);
            emit hasSyncedLyricsChanged(false);
            emit loadingChanged(false);
            reply->deleteLater();
            return;
        }
    }

    reply->deleteLater();
    step3_FetchLrclibFuzzy();
}

void LyricsService::step3_FetchLrclibFuzzy() {
    QString combinedQuery = m_targetArtist.isEmpty() ? m_targetTitle : (m_targetArtist + " " + m_targetTitle);

    QUrl url("https://lrclib.net/api/search");
    QUrlQuery q;
    q.addQueryItem("q", combinedQuery);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "AetheriaMusicSuite/5.0");
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onLrclibFuzzyFinished);
}

void LyricsService::onLrclibFuzzyFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonArray results = QJsonDocument::fromJson(data).array();

        if (!results.isEmpty()) {
            QJsonObject bestMatch = results.first().toObject();
            QString synced = bestMatch.value("syncedLyrics").toString().trimmed();
            QString plain = bestMatch.value("plainLyrics").toString().trimmed();

            if (!synced.isEmpty()) {
                parseLrc(synced);
                reply->deleteLater();
                return;
            } else if (!plain.isEmpty()) {
                m_rawLyrics = plain;
                m_hasSynced = false;
                m_isLoading = false;
                emit rawLyricsChanged(m_rawLyrics);
                emit linesCountChanged(0);
                emit hasSyncedLyricsChanged(false);
                emit loadingChanged(false);
                reply->deleteLater();
                return;
            }
        }
    }

    reply->deleteLater();

    if (m_musixmatchToken.isEmpty()) {
        getMusixmatchTokenThenFetch();
    } else {
        step1_FetchMusixmatch();
    }
}

void LyricsService::getMusixmatchTokenThenFetch() {
    QUrl url("https://apic-desktop.musixmatch.com/ws/1.1/token.get");
    QUrlQuery q;
    q.addQueryItem("app_id", MXM_APP_ID);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onMusixmatchTokenFinished);
}

void LyricsService::onMusixmatchTokenFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QJsonObject body = root.value("message").toObject().value("body").toObject();
        QString token = body.value("user_token").toString();

        if (!token.isEmpty()) {
            m_musixmatchToken = token;
            QSettings settings("Aetheria", "MusicPlayer");
            settings.setValue("musixmatch_token", token);
        }
    }
    reply->deleteLater();

    step1_FetchMusixmatch();
}

void LyricsService::step1_FetchMusixmatch() {
    if (m_musixmatchToken.isEmpty()) {
        step4_FetchNetEase();
        return;
    }

    QUrl url("https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get");
    QUrlQuery q;
    q.addQueryItem("app_id", MXM_APP_ID);
    q.addQueryItem("user_token", m_musixmatchToken);
    q.addQueryItem("q_track", m_targetTitle);
    if (!m_targetArtist.isEmpty()) {
        q.addQueryItem("q_artist", m_targetArtist);
    }
    q.addQueryItem("format", "json");
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);
    req.setRawHeader("Cookie", "AWSELBCORS=0; AWSELB=0");

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onMusixmatchSubtitlesFinished);
}

void LyricsService::onMusixmatchSubtitlesFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QJsonObject body = root.value("message").toObject().value("body").toObject();
        QJsonObject macroCalls = body.value("macro_calls").toObject();

        QJsonObject subObj = macroCalls.value("track.subtitles.get").toObject().value("message").toObject().value("body").toObject().value("subtitle_list").toArray().first().toObject().value("subtitle").toObject();
        QString subtitleBody = subObj.value("subtitle_body").toString();

        if (!subtitleBody.isEmpty()) {
            parseMusixmatchSubtitlesJson(subtitleBody);
            reply->deleteLater();
            return;
        }
    }

    reply->deleteLater();
    step4_FetchNetEase();
}

void LyricsService::parseMusixmatchSubtitlesJson(const QString &jsonSubtitles) {
    m_lines.clear();
    QJsonArray arr = QJsonDocument::fromJson(jsonSubtitles.toUtf8()).array();

    for (const auto &val : arr) {
        QJsonObject item = val.toObject();
        QString text = item.value("text").toString().trimmed();
        QJsonObject timeObj = item.value("time").toObject();

        qint64 totalMs = (timeObj.value("minutes").toInteger() * 60 * 1000)
                         + (timeObj.value("seconds").toInteger() * 1000)
                         + (timeObj.value("hundredths").toInteger() * 10);

        if (!text.isEmpty()) {
            m_lines.append({totalMs, text});
        }
    }

    if (!m_lines.isEmpty()) {
        m_hasSynced = true;
        m_rawLyrics = "";
        m_isLoading = false;
        m_currentLineIndex = 0;

        emit rawLyricsChanged("");
        emit linesCountChanged(static_cast<int>(m_lines.size()));
        emit hasSyncedLyricsChanged(true);
        emit currentLineIndexChanged(0);
        emit loadingChanged(false);
    } else {
        step4_FetchNetEase();
    }
}

void LyricsService::step4_FetchNetEase() {
    QString query = m_targetArtist.isEmpty() ? m_targetTitle : (m_targetTitle + " " + m_targetArtist);

    QUrl url("https://music.163.com/api/search/get/web");
    QUrlQuery q;
    q.addQueryItem("s", query);
    q.addQueryItem("type", "1");
    q.addQueryItem("limit", "1");
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onNetEaseSearchFinished);
}

void LyricsService::onNetEaseSearchFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    QString songId = "";
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QJsonArray songs = root.value("result").toObject().value("songs").toArray();
        if (!songs.isEmpty()) {
            songId = QString::number(songs.first().toObject().value("id").toInteger());
        }
    }
    reply->deleteLater();

    if (!songId.isEmpty()) {
        QUrl lyrUrl("https://music.163.com/api/song/lyric");
        QUrlQuery q;
        q.addQueryItem("id", songId);
        q.addQueryItem("lv", "1");
        lyrUrl.setQuery(q);

        QNetworkRequest lyrReq(lyrUrl);
        lyrReq.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

        m_currentReply = m_networkManager->get(lyrReq);
        connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onNetEaseLyricsFinished);
    } else {
        step6_FetchPersianWeb();
    }
}

void LyricsService::onNetEaseLyricsFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject root = QJsonDocument::fromJson(data).object();
        QString lrc = root.value("lrc").toObject().value("lyric").toString().trimmed();

        if (!lrc.isEmpty() && lrc.contains("[00:")) {
            parseLrc(lrc);
            reply->deleteLater();
            return;
        }
    }
    reply->deleteLater();
    step6_FetchPersianWeb();
}

void LyricsService::step6_FetchPersianWeb() {
    QString query = QString("متن آهنگ %1 %2 site:horadi.com").arg(m_targetTitle, m_targetArtist).trimmed();

    QUrl url("https://html.duckduckgo.com/html/");
    QUrlQuery q;
    q.addQueryItem("q", query);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onDuckDuckGoSearchFinished);
}

void LyricsService::onDuckDuckGoSearchFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    QString targetUrl = "";
    if (reply->error() == QNetworkReply::NoError) {
        QString html = QString::fromUtf8(reply->readAll());
        static const QRegularExpression linkRx("class=\"result__url\"[^>]*href=\"([^\"]+)\"", QRegularExpression::CaseInsensitiveOption);
        QRegularExpressionMatchIterator it = linkRx.globalMatch(html);

        QStringList candidateUrls;
        while (it.hasNext()) {
            QString link = it.next().captured(1);
            if (link.contains("uddg=")) {
                link = QUrl::fromPercentEncoding(link.section("uddg=", 1, 1).section("&", 0, 0).toUtf8());
            }

            if (link.contains("horadi.com")) {
                targetUrl = link;
                break;
            } else if (link.contains("taktaraneh") || link.contains("musicfa") ||
                       link.contains("golsarmusic") || link.contains("upmusics") ||
                       link.contains("bia2music")) {
                candidateUrls.append(link);
            }
        }

        if (targetUrl.isEmpty() && !candidateUrls.isEmpty()) {
            targetUrl = candidateUrls.first();
        }
    }
    reply->deleteLater();

    if (!targetUrl.isEmpty()) {
        QNetworkRequest req((QUrl(targetUrl)));
        req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);

        m_currentReply = m_networkManager->get(req);
        connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onGenericWebPageFinished);
    } else {
        step5_FetchGenius();
    }
}

void LyricsService::onGenericWebPageFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QString html = QString::fromUtf8(reply->readAll());

        static const QRegularExpression headerRx("<header[^>]*>.*?</header>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression navRx("<nav[^>]*>.*?</nav>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression footerRx("<footer[^>]*>.*?</footer>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression asideRx("<aside[^>]*>.*?</aside>", QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);

        html.remove(headerRx);
        html.remove(navRx);
        html.remove(footerRx);
        html.remove(asideRx);

        QString cleanedText = cleanHtmlLyrics(html);
        QStringList allLines = cleanedText.split('\n', Qt::SkipEmptyParts);

        QStringList finalLyrics;
        bool collecting = false;

        for (const QString &rawLine : allLines) {
            QString line = rawLine.trimmed();
            if (line.isEmpty() || line == "•") continue;

            if (line.contains("Lyrics of", Qt::CaseInsensitive) ||
                line.contains("Lyrics :", Qt::CaseInsensitive) ||
                line.startsWith("متن آهنگ", Qt::CaseInsensitive) ||
                line.startsWith("تکست آهنگ", Qt::CaseInsensitive)) {
                collecting = true;
                continue;
            }

            if (line.contains("تگ‌ های این مقاله", Qt::CaseInsensitive) ||
                line.contains("تگ های این مقاله", Qt::CaseInsensitive) ||
                line.contains("برچسب ها", Qt::CaseInsensitive) ||
                line.contains("دانلود آهنگ", Qt::CaseInsensitive) ||
                line.contains("ارسال نظر", Qt::CaseInsensitive) ||
                line.contains("دیدگاهتان را بنویسید", Qt::CaseInsensitive) ||
                line.contains("box-download", Qt::CaseInsensitive) ||
                line.contains("دانلود با کیفیت", Qt::CaseInsensitive)) {
                if (collecting) break;
                continue;
            }

            if (line.contains("پخش آنلاین") || line.contains("0:00") || line.contains("کیفیت 320") || line.contains("کیفیت 128")) {
                continue;
            }

            if (collecting) {
                finalLyrics.append(line);
            }
        }

        if (finalLyrics.size() >= 3) {
            m_rawLyrics = finalLyrics.join("\n");
            m_hasSynced = false;
            m_isLoading = false;
            emit rawLyricsChanged(m_rawLyrics);
            emit linesCountChanged(0);
            emit hasSyncedLyricsChanged(false);
            emit loadingChanged(false);
            reply->deleteLater();
            return;
        }
    }
    reply->deleteLater();

    step5_FetchGenius();
}

void LyricsService::step5_FetchGenius() {
    QString query = m_targetArtist.isEmpty() ? m_targetTitle : (m_targetTitle + " " + m_targetArtist);

    QUrl url("https://genius.com/api/search/multi");
    QUrlQuery q;
    q.addQueryItem("per_page", "5");
    q.addQueryItem("q", query);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);
    req.setRawHeader("Accept", "application/json");

    m_currentReply = m_networkManager->get(req);
    connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onGeniusMultiSearchFinished);
}

void LyricsService::onGeniusMultiSearchFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    QString songPageUrl = "";
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QJsonObject rootObj = QJsonDocument::fromJson(data).object();
        QJsonArray sections = rootObj.value("response").toObject().value("sections").toArray();

        for (const auto &sec : sections) {
            QJsonObject secObj = sec.toObject();
            if (secObj.value("type").toString() == "song" || secObj.value("type").toString() == "top_hit") {
                QJsonArray hits = secObj.value("hits").toArray();
                if (!hits.isEmpty()) {
                    songPageUrl = hits.first().toObject().value("result").toObject().value("url").toString();
                    if (!songPageUrl.isEmpty()) break;
                }
            }
        }
    }
    reply->deleteLater();

    if (!songPageUrl.isEmpty()) {
        QNetworkRequest req((QUrl(songPageUrl)));
        req.setHeader(QNetworkRequest::UserAgentHeader, BROWSER_USER_AGENT);
        req.setRawHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");

        m_currentReply = m_networkManager->get(req);
        connect(m_currentReply, &QNetworkReply::finished, this, &LyricsService::onGeniusHtmlPageFinished);
    } else {
        m_rawLyrics = "No lyrics found for this track.";
        emit rawLyricsChanged(m_rawLyrics);
        m_isLoading = false;
        emit loadingChanged(false);
    }
}

void LyricsService::onGeniusHtmlPageFinished() {
    if (!m_currentReply) return;
    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() == QNetworkReply::NoError) {
        QString html = QString::fromUtf8(reply->readAll());

        static const QRegularExpression containerStartRegex("<div[^>]*data-lyrics-container=\"true\"[^>]*>");
        QRegularExpressionMatchIterator it = containerStartRegex.globalMatch(html);

        QString collectedHtml = "";
        while (it.hasNext()) {
            QRegularExpressionMatch match = it.next();
            int startIdx = match.capturedEnd();


            int depth = 1;
            int currentPos = startIdx;
            while (depth > 0 && currentPos < html.length()) {
                int nextOpen = html.indexOf("<div", currentPos, Qt::CaseInsensitive);
                int nextClose = html.indexOf("</div>", currentPos, Qt::CaseInsensitive);

                if (nextClose == -1) break;

                if (nextOpen != -1 && nextOpen < nextClose) {
                    depth++;
                    currentPos = nextOpen + 4;
                } else {
                    depth--;
                    if (depth == 0) {
                        collectedHtml += html.mid(startIdx, nextClose - startIdx) + "\n";
                    }
                    currentPos = nextClose + 6;
                }
            }
        }

        if (!collectedHtml.isEmpty()) {
            m_rawLyrics = cleanHtmlLyrics(collectedHtml);
            m_hasSynced = false;
            m_isLoading = false;
            emit rawLyricsChanged(m_rawLyrics);
            emit linesCountChanged(0);
            emit hasSyncedLyricsChanged(false);
            emit loadingChanged(false);
            reply->deleteLater();
            return;
        }
    }
    reply->deleteLater();

    m_rawLyrics = "No lyrics found for this track.";
    emit rawLyricsChanged(m_rawLyrics);
    m_isLoading = false;
    emit loadingChanged(false);
}

void LyricsService::parseLrc(const QString &lrcContent) {
    m_lines.clear();
    QStringList rawLines = lrcContent.split('\n', Qt::SkipEmptyParts);

    static const QRegularExpression rx("\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)");

    for (const QString &line : rawLines) {
        QRegularExpressionMatch match = rx.match(line.trimmed());
        if (match.hasMatch()) {
            qint64 min = match.captured(1).toLongLong();
            qint64 sec = match.captured(2).toLongLong();
            QString msStr = match.captured(3);
            qint64 ms = (msStr.length() == 2) ? (msStr.toLongLong() * 10) : msStr.toLongLong();

            qint64 totalMs = (min * 60 * 1000) + (sec * 1000) + ms;
            QString text = match.captured(4).trimmed();

            if (!text.isEmpty()) {
                m_lines.append({totalMs, text});
            }
        }
    }

    if (!m_lines.isEmpty()) {
        m_hasSynced = true;
        m_rawLyrics = "";
        m_isLoading = false;
        m_currentLineIndex = 0;


        if (!m_currentFilePath.isEmpty() && QSqlDatabase::contains("PMPlayerConnection")) {
            QSqlDatabase db = QSqlDatabase::database("PMPlayerConnection");
            if (db.isOpen()) {
                QSqlQuery q(db);
                q.prepare("UPDATE tracks SET synced_lyrics = :lyrics WHERE file_path = :path");
                q.bindValue(":lyrics", lrcContent);
                q.bindValue(":path", m_currentFilePath);
                q.exec();
            }
        }

        emit rawLyricsChanged("");
        emit linesCountChanged(static_cast<int>(m_lines.size()));
        emit hasSyncedLyricsChanged(true);
        emit currentLineIndexChanged(0);
        emit loadingChanged(false);
    } else {
        m_rawLyrics = lrcContent;
        m_hasSynced = false;
        m_isLoading = false;

        emit rawLyricsChanged(m_rawLyrics);
        emit linesCountChanged(0);
        emit hasSyncedLyricsChanged(false);
        emit loadingChanged(false);
    }
}

void LyricsService::updatePosition(qint64 positionMs) {
    if (!m_hasSynced || m_lines.isEmpty()) return;

    int activeIdx = -1;
    for (int i = 0; i < m_lines.size(); ++i) {
        if (positionMs >= m_lines.at(i).timestampMs) {
            activeIdx = i;
        } else {
            break;
        }
    }

    if (activeIdx != m_currentLineIndex) {
        m_currentLineIndex = activeIdx;
        emit currentLineIndexChanged(m_currentLineIndex);
    }
}
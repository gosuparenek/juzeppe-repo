package icu.juzeppe.bridge;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URLEncoder;
import java.net.HttpURLConnection;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Element;

/** Read the publicly available search page and playback links from Muzmos. */
final class MusicCatalog {
    private static final String ROOT = "https://muzmos.com";
    private static final int MAX_HTML = 2_000_000;
    private static final int MAX_TRACKS = 30;
    record Track(String title, String artist, URI audio) {}

    static List<Track> search(String query) throws IOException {
        URI url = URI.create(ROOT + "/search/?q=" + URLEncoder.encode(query, StandardCharsets.UTF_8));
        try (Response response = open(url, false)) {
            byte[] bytes = response.stream().readNBytes(MAX_HTML + 1);
            if (bytes.length > MAX_HTML) throw new IOException("Catalog response too large");
            return parse(new String(bytes, StandardCharsets.UTF_8), response.uri());
        }
    }

    static List<Track> parse(String html) {
        return parse(html, URI.create(ROOT + "/"));
    }

    static List<Track> parse(String html, URI base) {
        List<Track> tracks = new ArrayList<>();
        Set<URI> seen = new HashSet<>();
        // Skip promotional tracks in the page header.
        for (Element e : Jsoup.parse(html).select("a.snd-item[data-track][data-title]")) {
            URI uri;
            try {
                uri = base.resolve(e.attr("data-track"));
            } catch (IllegalArgumentException ex) {
                continue;
            }
            if (!isAudio(uri) || !seen.add(uri)) continue;
            String title = e.attr("data-title").strip();
            if (title.isEmpty()) continue;
            tracks.add(new Track(shortText(title), shortText(e.attr("data-artist")), uri));
            if (tracks.size() >= MAX_TRACKS) break;
        }
        return List.copyOf(tracks);
    }

    private static String shortText(String s) {
        return s.length() <= 180 ? s : s.substring(0, 180);
    }

    private static boolean isOrigin(URI uri) {
        return "https".equalsIgnoreCase(uri.getScheme()) &&
            isMuzmosHost(uri.getHost()) &&
            (uri.getPort() == -1 || uri.getPort() == 443) && uri.getUserInfo() == null;
    }

    private static boolean isMuzmosHost(String host) {
        if (host == null) return false;
        host = host.toLowerCase(java.util.Locale.ROOT);
        return host.equals("muzmos.com") ||
            host.matches("[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.muzmos\\.com");
    }

    private static boolean isSearchPath(URI uri) {
        String path = uri.getPath();
        if (path == null) return false;
        return path.equals("/search") || path.startsWith("/search/") ||
            (!"muzmos.com".equalsIgnoreCase(uri.getHost()) && path.equals("/"));
    }

    private static boolean isAudio(URI uri) {
        return isOrigin(uri) && uri.getPath() != null &&
            (uri.getPath().startsWith("/uploads/music/") &&
             uri.getPath().toLowerCase(java.util.Locale.ROOT).endsWith(".mp3") ||
             uri.getPath().matches("/get/[a-fA-F0-9]{16}\\.mp3")) &&
            uri.normalize().equals(uri) && uri.getQuery() == null && uri.getFragment() == null;
    }

    static InputStream audio(Track track) throws IOException {
        if (!isAudio(track.audio())) throw new IOException("Invalid catalog audio URL");
        return open(track.audio(), true).stream();
    }

    private record Response(URI uri, InputStream stream) implements AutoCloseable {
        @Override public void close() throws IOException { stream.close(); }
    }

    private static Response open(URI uri, boolean audio) throws IOException {
        for (int redirect = 0; redirect <= 3; redirect++) {
            if (!isOrigin(uri) || (audio ? !isAudio(uri) : !isSearchPath(uri))) {
                throw new IOException("Unexpected Muzmos redirect destination");
            }
            HttpURLConnection connection = (HttpURLConnection) uri.toURL().openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setConnectTimeout(8000);
            connection.setReadTimeout(12000);
            connection.setRequestProperty("User-Agent", "JuzeppeOS Music/1.0");
            try {
                int status = connection.getResponseCode();
                if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
                    String location = connection.getHeaderField("Location");
                    connection.disconnect();
                    if (location == null) throw new IOException("Muzmos redirect without location");
                    uri = uri.resolve(location);
                    continue;
                }
                if (status != 200) throw new IOException("Muzmos HTTP " + status);
                return new Response(uri, new BufferedInputStream(connection.getInputStream()) {
                    @Override public void close() throws IOException {
                        try { super.close(); } finally { connection.disconnect(); }
                    }
                });
            } catch (IOException | IllegalArgumentException e) {
                connection.disconnect();
                throw new IOException(e.getMessage(), e);
            }
        }
        throw new IOException("Too many Muzmos redirects");
    }
}

package icu.juzeppe.bridge;

import java.nio.file.Files;
import java.nio.file.Path;

public final class MusicSmoke {
    public static void main(String[] args) throws Exception {
        var tracks = MusicCatalog.parse("""
            <div data-track="https://muzmos.com/uploads/music/header.mp3" data-title="Header">ignored</div>
            <a class="snd-item" data-track="https://muzmos.com/uploads/music/test.mp3"
               data-title="Song &amp; Piano" data-artist="Demo"></a>
            <a class="snd-item" data-track="https://muzmos.com/uploads/music/test.mp3" data-title="Duplicate"></a>
            <a class="snd-item" data-track="https://example.com/test.mp3" data-title="Foreign source"></a>
            """);
        if (tracks.size()!=1 || !tracks.get(0).title().equals("Song & Piano"))
            throw new AssertionError("Catalog markup parse or origin validation");
        var relative = MusicCatalog.parse("""
            <a class="snd-item search-track" data-track="/get/1234567890abcdef.mp3"
               data-title="Result" data-artist="Artist"></a>
            """, java.net.URI.create("https://queen.muzmos.com/"));
        if (relative.size()!=1 || !relative.get(0).audio().toString().equals("https://queen.muzmos.com/get/1234567890abcdef.mp3"))
            throw new AssertionError("Relative search result audio URL");
        long[] count = {0};
        boolean[] nonzero = {false};
        try (var input = Files.newInputStream(Path.of(args[0]))) {
            MusicDecoder.decode(input, samples -> {
                count[0] += samples.length;
                for (byte value : samples) if (value != 0) nonzero[0] = true;
            });
        }
        if (!nonzero[0] || count[0] < 8000 || count[0] > 20000)
            throw new AssertionError("MP3 decode sample count: " + count[0]);
        System.out.println("Verified generated MP3: " + count[0] + " signed 8-bit 48 kHz samples");
        if (args.length > 1) {
            var live = MusicCatalog.search("Кино Кукушка");
            System.out.println("Live Muzmos catalog result count: " + live.size());
            if (live.isEmpty()) throw new AssertionError("Live search returned no tracks");
            boolean[] streamed = {false};
            try (var input = MusicCatalog.audio(live.get(0))) {
                try {
                    MusicDecoder.decode(input, samples -> {
                        streamed[0] = samples.length > 0;
                        throw new InterruptedException("Smoke test complete");
                    });
                } catch (InterruptedException expected) {
                    if (!streamed[0]) throw expected;
                }
            }
            if (!streamed[0]) throw new AssertionError("Live track produced no audio");
            System.out.println("Verified first chunk of live MP3 stream");
        }
    }
}

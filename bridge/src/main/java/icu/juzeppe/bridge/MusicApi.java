package icu.juzeppe.bridge;

import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/** Bounded asynchronous HTTP and decoding; no heavy work on the server tick thread. */
public final class MusicApi implements ILuaAPI {
    private static ThreadPoolExecutor pool(int max, String name) {
        return new ThreadPoolExecutor(0, max, 30, TimeUnit.SECONDS,
            new java.util.concurrent.SynchronousQueue<>(), task -> {
                Thread thread = new Thread(task,name);
                thread.setDaemon(true);
                return thread;
            });
    }
    private static final ThreadPoolExecutor SEARCH = pool(4,"Juzeppe Music Search");
    private static final ThreadPoolExecutor AUDIO = pool(8,"Juzeppe Music Audio");
    private static final int MAX_QUERY = 160;

    private List<MusicCatalog.Track> tracks = List.of();
    private String searchState = "idle", searchError = "";
    private Future<?> searchTask;
    private long generation = 0;
    private Playback playback;

    private static final class Playback {
        final ArrayBlockingQueue<byte[]> queue = new ArrayBlockingQueue<>(4);
        volatile boolean done = false, cancelled = false;
        volatile String error = "";
        Future<?> task;

        void cancel() {
            cancelled = true;
            if (task != null) task.cancel(true);
            queue.clear();
        }
    }

    @Override public String[] getNames() { return new String[]{"juzeppeMusic"}; }
    @LuaFunction public int apiVersion() { return 1; }

    @LuaFunction
    public final synchronized Object[] search(String query) {
        query = query.strip();
        if (query.isEmpty() || query.length() > MAX_QUERY)
            return new Object[]{false,"Enter a song or artist (max 160 characters)"};
        if (searchTask != null) searchTask.cancel(true);
        final long request = ++generation;
        final String term = query;
        tracks = List.of();
        searchState = "loading";
        searchError = "";
        try {
            searchTask = SEARCH.submit(() -> {
                List<MusicCatalog.Track> result = List.of();
                String error = "";
                try { result = MusicCatalog.search(term); }
                catch (Exception e) { error = message(e); }
                synchronized (MusicApi.this) {
                    if (generation != request) return;
                    tracks = result;
                    searchError = error;
                    searchState = error.isEmpty() ? "ready" : "error";
                }
            });
            return new Object[]{true};
        } catch (RejectedExecutionException e) {
            searchState = "error";
            searchError = "Music search busy, try again";
            return new Object[]{false,searchError};
        }
    }

    @LuaFunction
    public final synchronized Map<String,Object> searchResult() {
        List<Map<String,Object>> results = new ArrayList<>();
        int index = 1;
        for (MusicCatalog.Track track : tracks) {
            results.add(Map.of("id",index++,"title",track.title(),"artist",track.artist()));
        }
        return Map.of("state",searchState,"error",searchError,"tracks",results);
    }

    @LuaFunction
    public final synchronized Object[] play(int index) {
        if (!"ready".equals(searchState) || index < 1 || index > tracks.size())
            return new Object[]{false,"Select a search result first"};
        stop();
        Playback next = new Playback();
        MusicCatalog.Track track = tracks.get(index-1);
        try {
            next.task = AUDIO.submit(() -> {
                try (InputStream audio = MusicCatalog.audio(track)) {
                    if (next.cancelled) return;
                    MusicDecoder.decode(audio, samples -> {
                        if (next.cancelled) throw new InterruptedException();
                        next.queue.put(samples);
                    });
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                } catch (Exception e) {
                    if (!next.cancelled) next.error = message(e);
                } finally {
                    next.done = true;
                }
            });
            playback = next;
            return new Object[]{true};
        } catch (RejectedExecutionException e) {
            return new Object[]{false,"Too many open music streams"};
        }
    }

    @LuaFunction
    public final synchronized Object[] nextChunk() {
        if (playback == null) return new Object[]{null,"stopped"};
        byte[] samples = playback.queue.poll();
        if (samples != null) {
            List<Integer> list = new ArrayList<>(samples.length);
            for (byte value : samples) list.add((int)value);
            return new Object[]{list,"playing"};
        }
        if (playback.done)
            return new Object[]{null,playback.error.isEmpty() ? "finished" : "error",playback.error};
        return new Object[]{null,"buffering"};
    }

    @LuaFunction
    public final synchronized void stop() {
        if (playback != null) playback.cancel();
        playback = null;
    }

    @Override public synchronized void shutdown() {
        stop();
        generation++;
        if (searchTask != null) searchTask.cancel(true);
        searchTask = null;
        tracks = List.of();
        searchState = "idle";
        searchError = "";
    }

    private static String message(Exception e) {
        String text = e.getMessage();
        if (text == null || text.isBlank()) text = e.getClass().getSimpleName();
        return text.length() > 180 ? text.substring(0,180) : text;
    }
}

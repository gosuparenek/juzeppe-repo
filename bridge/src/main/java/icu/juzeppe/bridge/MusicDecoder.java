package icu.juzeppe.bridge;

import java.io.InputStream;
import java.io.IOException;
import java.util.Arrays;
import javazoom.jl.decoder.Bitstream;
import javazoom.jl.decoder.Decoder;
import javazoom.jl.decoder.Header;
import javazoom.jl.decoder.SampleBuffer;

/** Convert MP3 frames to signed 8-bit mono PCM at 48 kHz for CC speakers. */
final class MusicDecoder {
    static final int CHUNK = 19200;
    static final long LIMIT = 48_000L * 60 * 60;
    interface Sink { void write(byte[] samples) throws InterruptedException; }

    static void decode(InputStream source, Sink sink) throws Exception {
        Bitstream stream = new Bitstream(source);
        Decoder decoder = new Decoder();
        byte[] chunk = new byte[CHUNK];
        int size = 0;
        int phase = 0;
        long total = 0;
        int sampleRate = 0;
        try {
            Header header;
            while (!Thread.currentThread().isInterrupted() && (header=stream.readFrame()) != null) {
                SampleBuffer pcm = (SampleBuffer) decoder.decodeFrame(header, stream);
                int channels = pcm.getChannelCount();
                int rate = pcm.getSampleFrequency();
                if (rate < 8000 || rate > 48000 || (channels != 1 && channels != 2))
                    throw new IOException("Unsupported audio format");
                if (rate != sampleRate) {
                    phase = 0;
                    sampleRate = rate;
                }
                short[] samples = pcm.getBuffer();
                int length = pcm.getBufferLength();
                for (int i=0; i+channels<=length; i+=channels) {
                    int mixed = samples[i];
                    if (channels == 2) mixed = (mixed + samples[i+1])/2;
                    byte sample = (byte) (mixed >> 8);
                    phase += 48000;
                    while (phase >= rate) {
                        phase -= rate;
                        chunk[size++] = sample;
                        if (++total > LIMIT) throw new IOException("Track exceeds one hour");
                        if (size == chunk.length) {
                            sink.write(chunk);
                            chunk = new byte[CHUNK];
                            size = 0;
                        }
                    }
                }
                stream.closeFrame();
            }
            if (Thread.currentThread().isInterrupted()) throw new InterruptedException();
            if (size > 0) sink.write(Arrays.copyOf(chunk,size));
            if (total == 0) throw new IOException("No MP3 audio received");
        } finally {
            stream.close();
        }
    }
}

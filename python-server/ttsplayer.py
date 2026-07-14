import asyncio
import logging

import av
import edge_tts
import sounddevice as sd

logger = logging.getLogger(__name__)


class TTSStreamer:
    async def stream(self, text: str, voice: str = "fr-FR-HenriNeural", **kwargs):
        communicate = edge_tts.Communicate(text, voice=voice, **kwargs)
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                yield chunk["data"]


class AudioDecoder:
    def __init__(self):
        self.codec = av.CodecContext.create('mp3', 'r')
        self.resampler = av.audio.resampler.AudioResampler(format='fltp')

    def decode(self, chunk: bytes):
        if not chunk:
            return

        try:
            packets = self.codec.parse(chunk)
            for packet in packets:
                if packet is None or packet.size == 0:
                    continue

                frames = self.codec.decode(packet)
                for frame in frames:
                    if not frame:
                        continue

                    # Resampling vers Float32 Planar (mono/stéréo géré)
                    resampled = self.resampler.resample(frame)
                    for r_frame in resampled:
                        # Transposition (channels, samples) -> (samples, channels)
                        audio_data = r_frame.to_ndarray().T
                        yield audio_data, r_frame.sample_rate, len(r_frame.layout.channels)

        except av.FFmpegError:
            pass  # ignore parsing error, may be introduced when reading MP3 stream (e.g. missing header)


class AudioPlayer:
    def __init__(self):
        self.stream = None

    def play(self, audio_data, sample_rate, channels):
        if self.stream is None:
            self.stream = sd.OutputStream(
                samplerate=sample_rate,
                channels=channels,
                dtype='float32'
            )
            self.stream.start()
        try:
            self.stream.write(audio_data)
        except:
            pass

    def close(self):
        try:
            self.stream.stop()
            self.stream.close()
        except:
            pass
        finally:
            self.stream = None


class TTSPlayerPipeline:
    def __init__(self):
        self.streamer = TTSStreamer()
        self.decoder = AudioDecoder()
        self.player = AudioPlayer()
        self._stop_event = asyncio.Event()

    async def play(self, text: str, voice: str = "fr-FR-HenriNeural", **kwargs):
        try:
            async for mp3_chunk in self.streamer.stream(text, voice=voice, **kwargs):
                if self._stop_event.is_set():
                    break
                for audio_data, rate, channels in self.decoder.decode(mp3_chunk):
                    await asyncio.to_thread(self.player.play, audio_data, rate, channels)
        except asyncio.CancelledError:
            self._stop_event.set()
            raise
        finally:
            await asyncio.to_thread(self.player.close)

    async def stop(self):
        self._stop_event.set()
        await asyncio.to_thread(self.player.close)

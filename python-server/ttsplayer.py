import asyncio
import logging
import numpy as np
import av
import edge_tts
import sounddevice as sd

logger = logging.getLogger(__name__)

# Constants for fixed audio format
SAMPLE_RATE = 24000
CHANNELS = 1

class TTSStreamer:
    """Handles streaming raw MP3 chunks from Edge-TTS."""
    async def stream(self, text: str, voice: str = "fr-FR-HenriNeural", **kwargs):
        communicate = edge_tts.Communicate(text, voice=voice, **kwargs)
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                yield chunk["data"]

class AudioDecoder:
    """Decodes MP3 chunks into raw float32 planar audio frames using PyAV."""
    def __init__(self):
        self.codec = av.CodecContext.create('mp3', 'r')
        self.resampler = av.audio.resampler.AudioResampler(
            format='fltp',
            layout='mono',
            rate=SAMPLE_RATE
        )

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
                    resampled = self.resampler.resample(frame)
                    for r_frame in resampled:
                        # Transpose from (channels, samples) to (samples, channels)
                        audio_data = r_frame.to_ndarray().T
                        yield audio_data
        except av.FFmpegError as e:
            logger.warning(f"FFmpeg decoding error ignored: {e}")

class AudioPlayer:
    """Manages a single persistent sounddevice OutputStream using constant parameters."""
    def __init__(self):
        self.stream = None

    def play(self, audio_data):
        if self.stream is None:
            self.stream = sd.OutputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype='float32'
            )
            self.stream.start()
        
        self.stream.write(audio_data.astype(np.float32))

    def close(self):
        if self.stream is not None:
            try:
                self.stream.stop()
                self.stream.close()
            except Exception as e:
                logger.error(f"Error while closing audio stream: {e}")
            finally:
                self.stream = None

class TTSPlayerPipeline:
    """Coordinates streaming, decoding, and thread-safe playback with constant audio format."""
    def __init__(self):
        self.streamer = TTSStreamer()
        self.decoder = AudioDecoder()
        self.player = AudioPlayer()
        self._stop_event = asyncio.Event()
        self._lock = asyncio.Lock() # protect AudioPlayer against race conditions

    async def play(self, text: str, voice: str = "fr-FR-HenriNeural", **kwargs):
        async with self._lock:
            try:
                self._stop_event.clear()
                async for mp3_chunk in self.streamer.stream(text, voice=voice, **kwargs):
                    if self._stop_event.is_set():
                        break
                    for audio_data in self.decoder.decode(mp3_chunk):
                        if self._stop_event.is_set():
                            break
                        # Execute blocking write in a dedicated thread safely
                        await asyncio.to_thread(self.player.play, audio_data)
            finally:
                await asyncio.to_thread(self.player.close)

    async def stop(self):
        self._stop_event.set()

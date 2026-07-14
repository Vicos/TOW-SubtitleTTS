#!/usr/bin/env python
import asyncio
import json
import logging

from ttsplayer import TTSPlayerPipeline

PIPE_NAME = r"\\.\pipe\TheOuterWorlds_TTS_Pipe"
logger = logging.getLogger(__name__)


# noinspection PyAttributeOutsideInit
class SubtitleTTSPipe(asyncio.Protocol):

    def __init__(self) -> None:
        self.pipeline = TTSPlayerPipeline()

    def connection_made(self, transport):
        logger.info("Client connected")
        self.transport = transport

    def data_received(self, data):
        message = data.decode('utf-8', errors='ignore').strip()
        logger.info(f"Received: {message}")
        asyncio.create_task(self._handle(message))

    def connection_lost(self, exc):
        logger.info("Client disconnected")
        self.transport.close()

    async def _handle(self, message: str) -> None:
        """Handle messages received from pipe."""
        payload = json.loads(message)
        action = payload.get("action", None)

        if action == "speak":
            text = payload.get("text", "")
            voice = payload.get("voice", "fr-FR-HenriNeural")
            volume = payload.get("volume", 100)
            relative_volume = volume - 100
            pitch = payload.get("pitch", 10)
            rate = payload.get("rate", 1)
            relative_rate_percent = int((1.35 ** (rate / 2.0) - 1) * 100)  # apply exponential curve, rate=2 -> +35%
            voice_params = {
                "voice": voice,
                "volume": f"{relative_volume:+}%",
                "pitch": f"{pitch:+}Hz",
                "rate": f"{relative_rate_percent:+}%",
            }
            await self._speak(text, **voice_params)

        elif action == "stop":
            logger.info("Stop speaking")
            await self.pipeline.stop()

        else:
            logger.error(f"Unknown action: {action}")

    async def _speak(self, text: str, **kwargs) -> None:
        """Generate audio and play *text*, respecting the current speech-active flag."""
        logger.info(f"Speaking with {len(text)} chars")
        await self.pipeline.play(text, **kwargs)


async def main():
    loop = asyncio.get_event_loop()
    await loop.start_serving_pipe(SubtitleTTSPipe, PIPE_NAME)

    logger.info(f"Server started")
    await asyncio.Event().wait()


if __name__ == "__main__":
    from rich.logging import RichHandler

    logging.basicConfig(level=logging.DEBUG, format="%(message)s", handlers=[RichHandler()])
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info(f"Server stopped")

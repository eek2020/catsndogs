"""Audio implementation using pygame.mixer."""

import os
import pygame

from whisper_crystals.core.interfaces import AudioInterface


import logging

logger = logging.getLogger(__name__)

class PygameAudio(AudioInterface):
    """Audio implementation using pygame.mixer.
    
    Loads audio assets from data_root/../assets/audio.
    """

    def __init__(self, project_root: str) -> None:
        self.audio_dir = os.path.join(project_root, "assets", "audio")
        self._sfx_cache: dict[str, pygame.mixer.Sound] = {}
        self._volume: float = 1.0

        # Ensure mixer is initialized
        if not pygame.mixer.get_init():
            try:
                # Default init parameters
                pygame.mixer.init()
            except pygame.error:
                pass

    def play_sfx(self, sfx_id: str) -> None:
        if not pygame.mixer.get_init():
            return
            
        if sfx_id not in self._sfx_cache:
            path = os.path.join(self.audio_dir, "sfx", f"{sfx_id}.wav")
            # Fallback to .ogg or .mp3 if .wav doesn't exist
            if not os.path.exists(path):
                path = os.path.join(self.audio_dir, "sfx", f"{sfx_id}.ogg")
            if not os.path.exists(path):
                path = os.path.join(self.audio_dir, "sfx", f"{sfx_id}.mp3")
                
            if os.path.exists(path):
                try:
                    sound = pygame.mixer.Sound(path)
                    sound.set_volume(self._volume)
                    self._sfx_cache[sfx_id] = sound
                except pygame.error:
                    logger.warning("Failed to load sfx: %s", path)
                    return
            else:
                return # Can't find file, ignore for prototyping
                
        if sfx_id in self._sfx_cache:
            channel = self._sfx_cache[sfx_id].play()
            logger.debug("Playing SFX: %s, channel: %s", sfx_id, channel)

    def play_music(self, music_id: str, loop: bool = True) -> None:
        if not pygame.mixer.get_init():
            return
            
        path = os.path.join(self.audio_dir, "music", f"{music_id}.ogg")
        # Fallback to .mp3 if .ogg doesn't exist
        if not os.path.exists(path):
            path = os.path.join(self.audio_dir, "music", f"{music_id}.mp3")
            
        if os.path.exists(path):
            try:
                pygame.mixer.music.load(path)
                pygame.mixer.music.set_volume(self._volume)
                pygame.mixer.music.play(-1 if loop else 0)
            except pygame.error:
                logger.warning("Failed to load music: %s", path)

    def stop_music(self) -> None:
        if pygame.mixer.get_init():
            pygame.mixer.music.stop()

    def set_volume(self, volume: float) -> None:
        self._volume = max(0.0, min(1.0, volume))
        if pygame.mixer.get_init():
            pygame.mixer.music.set_volume(self._volume)
            for sound in self._sfx_cache.values():
                sound.set_volume(self._volume)

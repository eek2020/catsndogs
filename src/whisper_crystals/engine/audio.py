"""Audio stub — implements AudioInterface as no-ops for Phase 1."""

from whisper_crystals.core.interfaces import AudioInterface


class PygameAudioStub(AudioInterface):
    """No-op audio implementation. Ready for real audio in Phase 2."""

    def play_sfx(self, sfx_id: str) -> None:
        pass

    def play_music(self, music_id: str, loop: bool = True) -> None:
        pass

    def stop_music(self) -> None:
        pass

    def set_volume(self, volume: float) -> None:
        pass

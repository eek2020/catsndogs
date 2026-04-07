#!/bin/bash
# Rollback script to automatically revert import changes.
# Run this from the project root.

echo "Starting rollback..."
cd /Users/erichook-marshall/Downloads/git/catsndogs

# Restore original music
if [ -d "backup_assets/music" ]; then
    cp backup_assets/music/* godot/assets/audio/music/
    echo "Restored original music."
fi

# Remove newly added sfx
rm a godot/assets/audio/sfx/ui_select.ogg
rm -f godot/assets/audio/sfx/mission_completed.ogg
rm -f godot/assets/audio/sfx/warning.ogg
rm -f godot/assets/audio/sfx/combat_flee.ogg
rm -f godot/assets/audio/sfx/crystal_pickup.ogg
echo "Removed imported SFX."

# Remove UI assets
rm -f godot/assets/ui/icons.png
rm -f godot/assets/ui/Orbiteer-Bold.ttf
rm -f godot/assets/ui/DejaVuSans.ttf
echo "Removed imported UI textures & fonts."

# Restore music_manager.gd using git checkout
git checkout godot/scripts/autoload/music_manager.gd
echo "Restored music_manager.gd."

# Remove backup folder
rm -rf backup_assets

echo "Rollback complete!"

#!/bin/bash
cd /Users/erichook-marshall/Downloads/git/catsndogs

# Backup current music files
mkdir -p backup_assets/music
cp -n godot/assets/audio/music/*.ogg backup_assets/music/

echo "Creating UI assets..."
cp other_data/fonts/Orbiteer-Bold.ttf godot/assets/ui/
cp other_data/fonts/DejaVuSans.ttf godot/assets/ui/
cp other_data/textures/icons.png godot/assets/ui/

echo "Copying music files..."
cp other_data/music/core/menu/menu_master.ogg godot/assets/audio/music/theme_menu.ogg
cp other_data/music/core/space/Pioneer2.ogg godot/assets/audio/music/theme_navigation.ogg
cp other_data/music/core/ship-nearby/encounter.ogg godot/assets/audio/music/theme_combat.ogg
cp other_data/music/core/near-spacestation/minuet.ogg godot/assets/audio/music/theme_trade.ogg

echo "Copying SFX files..."
cp other_data/sounds/Interface/Click.ogg godot/assets/audio/sfx/ui_select.ogg
cp other_data/sounds/Interface/OK.ogg godot/assets/audio/sfx/mission_completed.ogg
# These files are directly in other_data/sounds/
cp other_data/sounds/warning.ogg godot/assets/audio/sfx/warning.ogg
cp other_data/sounds/alarm_emer.ogg godot/assets/audio/sfx/combat_flee.ogg
cp other_data/sounds/impact_chime.ogg godot/assets/audio/sfx/crystal_pickup.ogg

echo "Import Complete."

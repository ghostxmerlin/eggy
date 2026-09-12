# Asset provenance

- Character geometry is hand-built in Blender to resemble the classic Eggy appearance; it is not an official or extracted game model. Visual reference: [Nintendo's Eggy Party introduction](https://www.nintendo.com/jp/topics/article/520374b3-68ac-4d45-96a7-50bc2400cdd7). Rebuild the character with `art/build_character.py`; editable source: `art/cloud_racer.blend`. Course geometry, skin accessories, palette, interface, icon and sound cues were generated for this project. `art/build_assets.py` rebuilds the character, rounded mesh and sound cues.
- CloudSans-Medium / CloudSans-Heavy: renamed static subsets derived from Noto Sans SC, downloaded from the Google Fonts repository (`ofl/notosanssc/NotoSansSC[wght].ttf`). SIL Open Font License is included in `assets/fonts/OFL.txt`. Build with `art/build_fonts.py`; retain the full source font in `art/NotoSansSC.source.ttf` for future text additions.
- Runtime engine: Godot 4.7.2, official macOS universal build, MIT license. Download URL: `https://downloads.godotengine.org/?flavor=stable&platform=macos.universal&slug=macos.universal.zip&version=4.7.2`.
- No original Eggy Party game assets or extracted audio are used.

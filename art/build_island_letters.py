"""Bevel the validated Godot glyph meshes; retain editable modifiers in Blender.
Run art/export_letter_meshes.gd with Godot first, then run this file in Blender.
"""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/island_letters_raw.glb'))
for obj in bpy.context.scene.objects:
    if obj.type!='MESH': continue
    bevel=obj.modifiers.new('Soft toy edges','BEVEL')
    bevel.width=.045; bevel.segments=3; bevel.limit_method='ANGLE'
    bevel.use_clamp_overlap=True
    normals=obj.modifiers.new('Stable face normals','WEIGHTED_NORMAL')
    normals.keep_sharp=True; normals.weight=50
    for face in obj.data.polygons: face.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/island_monument.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/island_letters.glb'),export_format='GLB',export_yup=True,export_apply=True)

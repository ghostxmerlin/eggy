"""Hand-built round yellow racer. Blender Z-up, front -Y; GLTF exports Y-up.

Run: Blender --background --python art/build_character.py
Append -- --preview to render a three-quarter inspection image into /private/tmp.
No downloaded meshes/textures are used. Semantic material names are the runtime
appearance API, and the four independent limb origins are the animation API.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
# Stable material resource names on repeated execution in the same Blender file.
for old in list(bpy.data.materials):
    bpy.data.materials.remove(old)


def material(name, color, roughness=.43):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Coat Weight'].default_value = .13
    shader.inputs['Coat Roughness'].default_value = .36
    return mat


shell = material('Shell', (1.0, .72, .045))
face = material('Face', (1.0, .68, .40), .50)
white = material('White', (.95, .95, .91), .48)
sole = material('Sole', (.67, .70, .72), .56)
eye = material('Eye', (.014, .011, .010), .34)
mouth = material('Mouth', (.065, .025, .013), .52)
blush = material('Blush', (1.0, .40, .27), .58)


def smooth(obj, mat):
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def sphere(name, position, scale, mat, segments=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return smooth(obj, mat)


def tube(name, points, radius, mat):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = point.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return obj


def merge(objects, active, name, origin):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = name
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return active


def front_y(x, z, offset=.009):
    return -.625 * math.sqrt(max(.001, 1-(x/.73)**2-((z-1)/.71)**2)) - offset


body = sphere('Round shell', (0, 0, 1), (.73, .625, .71), shell, 64, 40)
rigid = [body]
# Face is a closely fitted curved circular patch, not a second protruding head.
# Concentric rings track the exact body ellipsoid and avoid coplanar flicker.
verts = [(0, front_y(0, 1.065), 1.065)]
faces = []
segments, rings = 64, 16
for ring in range(1, rings+1):
    radius = ring/rings
    for step in range(segments):
        angle = 2*math.pi*step/segments
        x = .535*radius*math.cos(angle)
        z = 1.065 + .50*radius*math.sin(angle)
        verts.append((x, front_y(x, z), z))
for step in range(segments):
    faces.append((0, 1+step, 1+(step+1)%segments))
for ring in range(1, rings):
    inner = 1+(ring-1)*segments
    outer = inner+segments
    for step in range(segments):
        nxt = (step+1)%segments
        faces.append((inner+step, outer+step, outer+nxt, inner+nxt))
mesh = bpy.data.meshes.new('Fitted face patch')
mesh.from_pydata(verts, [], faces)
mesh.update()
patch = bpy.data.objects.new('Peach face', mesh)
bpy.context.collection.objects.link(patch)
# Ring winding points outward toward the character front (-Y).
smooth(patch, face)
rigid.append(patch)
for sign in (-1, 1):
    x, z = .176*sign, 1.145
    rigid.append(sphere('Friendly eye', (x, front_y(x, z, .021), z), (.038, .022, .074), eye, 28, 20))
    x, z = .316*sign, 1.005
    cheek = sphere('Subtle cheek', (x, front_y(x, z, .017), z), (.064, .012, .028), blush, 28, 16)
    cheek.rotation_euler.z = -.30*sign
    rigid.append(cheek)
smile_points = []
for x, z in [(-.071, 1.015), (-.04, .987), (0, .976), (.04, .987), (.071, 1.015)]:
    smile_points.append((x, front_y(x, z, .020), z))
rigid.append(tube('Little smile', smile_points, .010, mouth))
# Tiny soft stalk and ball stay on the merged rigid body during a roll.
rigid.append(sphere('Antenna stalk', (0, .015, 1.765), (.044, .044, .105), shell, 28, 20))
rigid.append(sphere('Antenna ball', (0, .015, 1.875), (.125, .125, .125), shell, 36, 24))
merge(rigid, body, 'Body', (0, 0, 0))


def shoe_mesh(name, sign):
    # Elliptical ring profile gives the white sneaker a stable, flat outsole.
    # The separate material boundary remains clear without an extra mesh node.
    profile = [(0.0, .72), (.013, .93), (.047, 1.0), (.082, 1.0),
               (.099, .97), (.14, .98), (.21, .89), (.28, .66), (.325, .24)]
    center = Vector((sign*.32, -.11, .18))
    verts, faces, material_ids = [], [], []
    steps = 48
    for height, size in profile:
        for step in range(steps):
            angle = 2*math.pi*step/steps
            verts.append((.245*size*math.cos(angle), .335*size*math.sin(angle), height-.18))
    faces.append(tuple(reversed(range(steps))))
    material_ids.append(1)
    for ring in range(len(profile)-1):
        for step in range(steps):
            nxt = (step+1)%steps
            faces.append((ring*steps+step, ring*steps+nxt, (ring+1)*steps+nxt, (ring+1)*steps+step))
            material_ids.append(1 if ring < 3 else 0)
    faces.append(tuple((len(profile)-1)*steps+step for step in range(steps)))
    material_ids.append(0)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    obj.data.materials.append(white)
    obj.data.materials.append(sole)
    for poly, index in zip(obj.data.polygons, material_ids):
        poly.use_smooth = len(poly.vertices) == 4
        poly.material_index = index
    return obj


for sign, suffix in [(-1, 'L'), (1, 'R')]:
    origin = (sign*.70, .025, .72)
    arm = sphere('Arm'+suffix, origin, (.17, .175, .225), shell, 36, 24)
    # Downward/outward relaxed mittens, with original shoulder animation origins.
    for vertex in arm.data.vertices:
        vertex.co.x += sign*.030
        vertex.co.y -= .025
        vertex.co.z -= .055
    arm.rotation_euler.y = -.20*sign
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    shoe_mesh('Foot'+suffix, sign)

bpy.ops.object.select_all(action='DESELECT')
objects = list(bpy.context.scene.objects)
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'art/cloud_racer.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, 'assets/models/racer.glb'),
                          export_format='GLB', export_yup=True, use_selection=True)
report = {}
for obj in objects:
    world = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    report[obj.name] = {'origin_blender': list(obj.location),
                        'min_blender': [min(v[i] for v in world) for i in range(3)],
                        'max_blender': [max(v[i] for v in world) for i in range(3)],
                        'materials': [m.name for m in obj.data.materials],
                        'triangles': sum(len(p.vertices)-2 for p in obj.data.polygons)}
print('CHARACTER_REPORT='+json.dumps(report, sort_keys=True))

if '--preview' in sys.argv:
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.world.color = (.24, .24, .24)
    scene.view_settings.view_transform = 'AgX'
    for name, position, energy, size in [('Key', (-3, -4, 6), 450, 4), ('Fill', (3, -2, 3), 180, 3), ('Rim', (1, 3, 5), 350, 3)]:
        bpy.ops.object.light_add(type='AREA', location=position)
        lamp = bpy.context.object
        lamp.name = name
        lamp.data.energy = energy
        lamp.data.shape = 'DISK'
        lamp.data.size = size
        lamp.rotation_euler = (Vector((0, 0, 1))-lamp.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add(location=(2.8, -7, 2.8))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 1))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.7
    scene.camera = camera
    scene.render.film_transparent = True
    scene.render.filepath = '/private/tmp/eggy-character-preview.png'
    bpy.ops.render.render(write_still=True)

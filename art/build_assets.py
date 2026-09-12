"""Reproducible original toy racer, modeled in Blender; +Y up after GLTF export."""
import bpy, math, os, wave, struct, random
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name, color, rough=.35, metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough; bs.inputs['Metallic'].default_value=metal
    bs.inputs['Coat Weight'].default_value=.25; bs.inputs['Coat Roughness'].default_value=.3
    return m
cream=material('Vanilla porcelain',(.98,.88,.64)); teal=material('Lagoon helmet',(.035,.59,.55))
orange=material('Apricot scarf',(.98,.25,.09)); dark=material('Espresso eyes',(.035,.07,.09),.22)
white=material('Milk highlights',(1,.98,.91)); pink=material('Peach cheeks',(1,.37,.31))
gold=material('Butter badge',(1,.67,.12),.28,.15)
parts=[]
def uv(name, loc, scale, mat, seg=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    parts.append(o); return o

def tube(name, points, radius, mat):
    cv=bpy.data.curves.new(name,'CURVE'); cv.dimensions='3D'; cv.bevel_depth=radius; cv.bevel_resolution=3
    sp=cv.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):p.co=co; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cv); bpy.context.collection.objects.link(o); o.data.materials.append(mat)
    bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o.select_set(False); parts.append(o); return o

body=uv('Shell',(0,0,1.0),(.69,.61,.84),cream,48,32)
for v in body.data.vertices:
    t=v.co.z/.84; v.co.x*=1-.14*t; v.co.y*=1-.14*t
# Open-faced crown with fitted ear cups and a raised seam.
uv('Crown',(0,.075,1.63),(.58,.50,.30),teal,40,24)
tube('Helmet seam',[(-.50,-.17,1.65),(-.28,-.40,1.76),(0,-.46,1.79),(.28,-.40,1.76),(.50,-.17,1.65)],.032,white)
for x in [-1,1]:
    uv('Headphone',(.61*x,.04,1.32),(.13,.29,.30),orange)
    uv('Headphone pad',(.718*x,.04,1.32),(.045,.17,.18),gold)
    uv('Eye',(.235*x,-.558,1.19),(.067,.05,.105),dark,24,16)
    uv('Eye sparkle',(.218*x,-.603,1.227),(.019,.012,.025),white,16,10)
    uv('Blush',(.36*x,-.521,1.01),(.094,.025,.046),pink,24,12)
tube('Smile',[(-.08,-.592,1.02),(0,-.614,.977),(.08,-.592,1.02)],.016,dark)
uv('Scarf collar',(0,0,.52),(.59,.53,.13),orange)
uv('Scarf knot',(.38,-.38,.55),(.16,.13,.13),gold)
tube('Scarf tail',[(.35,.24,.54),(.51,.48,.42),(.46,.65,.26)],.10,orange)
uv('Badge',(0,-.538,.73),(.105,.028,.105),gold)
# Two little soft fins on the helmet.
a=uv('Crest left',(-.12,.08,1.985),(.08,.10,.20),gold); a.rotation_euler.y=-.38
a=uv('Crest right',(.13,.08,1.96),(.08,.10,.17),orange); a.rotation_euler.y=.5
# Merge rigid shell with materials, reducing scene overhead.
bpy.ops.object.select_all(action='DESELECT')
for p in parts:p.select_set(True)
bpy.context.view_layer.objects.active=body; bpy.ops.object.join(); body.name='Body'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for x,suffix in [(-1,'L'),(1,'R')]:
    uv('Arm'+suffix,(x*.70,.025,.72),(.18,.20,.28),cream,24,16)
    uv('Foot'+suffix,(x*.32,-.11,.18),(.25,.32,.18),teal,28,16)
# Export edit source and real-time model.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art/cloud_racer.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/racer.glb'),export_format='GLB',export_yup=True)
# Unit rounded cube with normals baked for runtime instancing.
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_cube_add(size=1)
o=bpy.context.object; o.name='RoundedBlock'
b=o.modifiers.new('Soft molded corners','BEVEL'); b.width=.10; b.segments=4
bpy.ops.object.modifier_apply(modifier=b.name)
n=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); n.keep_sharp=True; n.weight=50
bpy.ops.object.modifier_apply(modifier=n.name)
for p in o.data.polygons:p.use_smooth=True
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/rounded.glb'),export_format='GLB')
# Tiny designed synthesis cues. Entirely generated, no third-party recordings.
def audio(name, duration, notes, volume=.2):
    rate=22050; samples=[]
    for i in range(int(rate*duration)):
        t=i/rate; n=min(len(notes)-1,int(t/duration*len(notes))); f=notes[n]
        local=(t/duration*len(notes))%1; env=min(1,local*24)*math.exp(-local*4)
        val=(math.sin(2*math.pi*f*t)+.25*math.sin(2*math.pi*f*2*t))*env*volume
        samples.append(struct.pack('<h',int(max(-1,min(1,val))*32767)))
    with wave.open(os.path.join(ROOT,'assets/audio',name+'.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
audio('jump',.18,[430,640],.12);audio('roll',.26,[180,240,360],.12)
audio('checkpoint',.5,[523,659,784],.17);audio('finish',1.25,[523,659,784,1047],.2)
audio('tick',.13,[700],.10);audio('go',.45,[700,1047],.14);audio('fall',.4,[370,280,180],.10)
print('Original assets exported.')

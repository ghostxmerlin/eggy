"""Reproducible racer, rounded track mesh, and synthesized gameplay sounds."""
import bpy, math, os, wave, struct, random, runpy
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
runpy.run_path(os.path.join(ROOT, 'art/build_character.py'), run_name='__main__')
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

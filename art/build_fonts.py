"""Subset OFL Noto Sans SC into original-named static UI fonts."""
from fontTools.ttLib import TTFont
from fontTools import subset
from fontTools.varLib.instancer import instantiateVariableFont
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
source=ROOT/'art/NotoSansSC.source.ttf'
if not source.exists(): (ROOT/'assets/fonts/NotoSansSC.ttf').rename(source)
text=''.join(p.read_text() for p in (ROOT/'scripts').glob('*.gd'))
text+=''.join(chr(i) for i in range(32,127))+'，。！：、→↗▼·'
font=TTFont(source)
options=subset.Options(); options.name_IDs=['*'];options.name_languages=['*']
sub=subset.Subsetter(options=options);sub.populate(text=text);sub.subset(font)
for weight,name in [(500,'CloudSans-Medium'),(800,'CloudSans-Heavy')]:
    static=instantiateVariableFont(font,{'wght':weight},inplace=False)
    for record in static['name'].names:
        if record.nameID in (1,4,6,16): record.string=name.encode(record.getEncoding())
    static.save(ROOT/'assets/fonts'/f'{name}.ttf')
    print(name, (ROOT/'assets/fonts'/f'{name}.ttf').stat().st_size)

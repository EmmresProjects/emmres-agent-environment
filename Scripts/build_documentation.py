from pathlib import Path
import json, zipfile, html, re, shutil, sys
ROOT=Path(__file__).resolve().parents[1]; DOCS=ROOT/'docs'; DOCS.mkdir(exist_ok=True)
CATS=DOCS/'catalogs'; CATS.mkdir(exist_ok=True)
for p in CATS.iterdir():
    if p.is_file(): p.unlink()
with zipfile.ZipFile(ROOT/'Skills_Catalogs.xml') as z:
    for name in sorted(z.namelist(),key=str.lower):
        if name.endswith('/') or '..' in Path(name).parts: continue
        b=z.read(name)
        try: t=b.decode('utf-8-sig')
        except UnicodeDecodeError: continue
        (CATS/Path(name).name).write_text(t,encoding='utf-8')

def h(x): return html.escape(str(x),quote=True)
def slug(x): return re.sub(r'[^a-z0-9]+','-',x.lower()).strip('-')
def page(title,body,depth=0):
    pre='../'*depth
    nav=f'''<nav><a href="{pre}index.html">Home</a><a href="{pre}tools/index.html">Tools</a><a href="{pre}environment/index.html">Environment</a><a href="{pre}downloads/index.html">Downloads</a><a href="{pre}catalogs/index.html">Catalogs</a><a href="{pre}catalog.json">JSON</a></nav>'''
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="{h(title)}"><title>{h(title)}</title><link rel="stylesheet" href="{pre}assets/site.css"></head><body><a class="skip" href="#main">Skip to content</a><header><strong>Emmre's Agent Environment</strong>{nav}</header><main id="main">{body}</main><footer>Agent-readable environment documentation</footer></body></html>'''

assets=DOCS/'assets'; assets.mkdir(exist_ok=True)
(assets/'site.css').write_text(''':root{color-scheme:light dark;--b:#081321;--p:#102238;--l:#2b4a69;--t:#eff7ff;--m:#b7c7d8;--a:#78c5ff}*{box-sizing:border-box}body{margin:0;background:var(--b);color:var(--t);font:16px/1.55 system-ui,Segoe UI,sans-serif}header,main,footer{max-width:1180px;margin:auto;padding:24px}nav{display:flex;flex-wrap:wrap;gap:14px;margin-top:12px}a{color:var(--a)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:15px}.card,.panel{background:var(--p);border:1px solid var(--l);border-radius:14px;padding:18px}.meta{color:var(--m)}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px;border-bottom:1px solid var(--l);vertical-align:top}.scroll{overflow:auto}.button{display:inline-block;padding:9px 13px;border:1px solid var(--a);border-radius:9px;text-decoration:none;margin:3px}input{width:100%;padding:13px;border:1px solid var(--l);border-radius:9px;font:inherit}.skip{position:absolute;left:-9999px}.skip:focus{left:10px;top:10px;background:white;color:black;padding:8px}code{overflow-wrap:anywhere}''',encoding='utf-8')

# Exact external tools represented by the installer, separated from Python packages and skill catalogs.
tools=[
('Runtime','uv','Portable Python and package/environment manager','https://github.com/astral-sh/uv/releases/latest','tools/uv/'),
('Runtime','Python 3.12','Managed portable CPython runtime','https://www.python.org/downloads/','python/'),
('Web and coding','Node.js LTS','Portable Node.js, npm, and npx','https://nodejs.org/en/download','tools/node/'),
('Android','Android Platform Tools','adb and fastboot without emulator images','https://developer.android.com/tools/releases/platform-tools','tools/platform-tools/'),
('Media','FFmpeg and FFprobe','Audio and video conversion, inspection, and encoding','https://www.gyan.dev/ffmpeg/builds/','tools/ffmpeg/'),
('Android','Eclipse Temurin JRE 17','Portable Java runtime used by APKTool','https://adoptium.net/temurin/releases/?version=17','tools/java/'),
('Android','APKTool','APK resource inspection and rebuilding','https://github.com/iBotPeaches/Apktool/releases/latest','tools/apktool/'),
('Developer utilities','Portable Git','Portable Git command-line environment','https://github.com/git-for-windows/git/releases/latest','tools/git/'),
('Archives','7-Zip 7zr','Portable archive extraction command','https://www.7-zip.org/download.html','bin/7zr.exe'),
('Data utilities','jq','JSON command-line processor','https://github.com/jqlang/jq/releases/latest','bin/jq.exe'),
('Data utilities','yq','YAML, JSON, and XML command-line processor','https://github.com/mikefarah/yq/releases/latest','bin/yq.exe'),
('Search utilities','ripgrep','Fast recursive text search','https://github.com/BurntSushi/ripgrep/releases/latest','tools/ripgrep/'),
('Search utilities','fd','Fast filesystem search','https://github.com/sharkdp/fd/releases/latest','tools/fd/'),
('Voice','Kokoro ONNX voice runtime','Offline speech generation runtime and model assets','https://github.com/thewh1teagle/kokoro-onnx','models/voice/kokoro/'),
]
manifest=None
mp=DOCS/'environment-manifest.json'
if mp.exists():
    try: manifest=json.loads(mp.read_text('utf-8-sig'))
    except Exception: pass
verified={str(x.get('name','')).lower() for x in (manifest or {}).get('tools',[])}

bycat={}
for cat,name,desc,url,path in tools: bycat.setdefault(cat,[]).append((name,desc,url,path))
( DOCS/'tools').mkdir(exist_ok=True)
for cat,entries in bycat.items():
    body=f'<h1>{h(cat)}</h1><p>Download sources and installed paths for this tool category.</p><section class="grid">'
    for name,desc,url,path in entries:
        state='Verified in latest successful build' if name.split()[0].lower() in verified else 'Installer-managed'
        body+=f'<article class="card"><h2>{h(name)}</h2><p>{h(desc)}</p><p class="meta">{h(state)} · Installed path: <code>Emmres_Environment/{h(path)}</code></p><a class="button" href="../downloads/index.html">Open local downloads</a></article>'
    body+='</section>'
    f=DOCS/'tools'/f'{slug(cat)}.html'; f.write_text(page(cat,body,1),encoding='utf-8')
tool_index='<h1>Tools</h1><p>External runtimes and command-line tools installed by the environment builder. These are separate from Python packages and skill catalogs.</p><section class="grid">'
for cat,entries in bycat.items(): tool_index+=f'<article class="card"><h2>{h(cat)}</h2><p>{len(entries)} tools</p><a href="{slug(cat)}.html">Open category</a></article>'
tool_index+='</section>'
(DOCS/'tools'/'index.html').write_text(page('Tools',tool_index,1),encoding='utf-8')

# Parse requirement categories from source headings.
sections=[]; current='Core Python and productivity'; pkgs=[]
for raw in (ROOT/'portable_requirements_v10.txt').read_text('utf-8').splitlines():
    x=raw.strip()
    if not x: continue
    if x.startswith('#'):
        if pkgs: sections.append((current,pkgs)); pkgs=[]
        current=x.lstrip('#').strip()
    else: pkgs.append(x)
if pkgs: sections.append((current,pkgs))
def normalize_packages(value):
    if isinstance(value, str):
        try: value=json.loads(value)
        except Exception: return []
    if isinstance(value, dict): value=[value]
    if not isinstance(value, list): return []
    result=[]
    for item in value:
        if isinstance(item, str):
            try: item=json.loads(item)
            except Exception: continue
        if isinstance(item, dict) and item.get('name'):
            result.append(item)
    return result
installed_packages=normalize_packages((manifest or {}).get('python',{}).get('packages',[]))
installed_versions={str(x.get('name','')).lower():str(x.get('version','')) for x in installed_packages}
(DOCS/'environment').mkdir(exist_ok=True)
env_cards=''
for cat,pkgs in sections:
    rows=''
    for spec in pkgs:
        base=re.split(r'[<>=!~\[]',spec,1)[0].strip(); version=installed_versions.get(base.lower(),'Resolved during installation')
        rows+=f'<tr id="{slug(base)}"><td>{h(base)}</td><td>{h(spec)}</td><td>{h(version)}</td></tr>'
    body=f'<h1>{h(cat)}</h1><p>Python packages in this environment category. Each package name links to its official PyPI project and downloadable distributions.</p><div class="panel scroll"><table><thead><tr><th>Package</th><th>Requirement</th><th>Installed version</th></tr></thead><tbody>{rows}</tbody></table></div>'
    (DOCS/'environment'/f'{slug(cat)}.html').write_text(page(cat,body,1),encoding='utf-8')
    env_cards+=f'<article class="card"><h2>{h(cat)}</h2><p>{len(pkgs)} packages</p><a href="{slug(cat)}.html">Open category</a></article>'
env_body=f'<h1>Python environment</h1><p>{sum(len(x[1]) for x in sections)} declared packages organized by capability. Download the complete requirements file or open a category.</p><p><a class="button" href="../../portable_requirements_v10.txt" download>Download requirements.txt</a></p><section class="grid">{env_cards}</section>'
(DOCS/'environment'/'index.html').write_text(page('Python environment',env_body,1),encoding='utf-8')

# Catalogs have their own dedicated landing page.
cat_items=[]
for p in sorted(CATS.iterdir(),key=lambda x:x.name.lower()):
    if not p.is_file() or p.name=='index.html': continue
    t=p.read_text('utf-8',errors='replace'); first=next((y.strip() for y in t.splitlines() if y.strip()),p.stem)
    cat_items.append({'name':p.stem.replace('_',' ').replace('-',' '),'file':p.name,'summary':first,'bytes':p.stat().st_size})
cat_cards=''.join(f'<article class="card item" data-search="{h((x["name"]+" "+x["summary"]).lower())}"><h2>{h(x["name"])}</h2><p>{h(x["summary"])}</p><a href="{h(x["file"])}">Open or download catalog</a></article>' for x in cat_items)
cat_body=f'''<h1>Skill and capability catalogs</h1><p>Catalog documents are separate from installed tools and Python packages.</p><label for="q">Search catalogs</label><input id="q" type="search"><p id="count">Showing all {len(cat_items)} catalogs.</p><section class="grid">{cat_cards}</section><script>const q=document.querySelector('#q'),a=[...document.querySelectorAll('.item')],c=document.querySelector('#count');q.addEventListener('input',()=>{{let n=0,s=q.value.toLowerCase();a.forEach(x=>{{let v=!s||x.dataset.search.includes(s);x.hidden=!v;if(v)n++}});c.textContent=`Showing ${{n}} of ${{a.length}} catalogs.`}});</script>'''
(CATS/'index.html').write_text(page('Catalogs',cat_body,1),encoding='utf-8')

# Download center: click-throughs to files and official binaries.
(DOCS/'downloads').mkdir(exist_ok=True)
dl=f'''<h1>Download center</h1><section class="grid"><article class="card"><h2>Environment installer</h2><p>Installs or repairs the full portable environment.</p><a class="button" href="../../Build_Emmres_Agent_Studio_v10.cmd" download>Download CMD</a><a class="button" href="../../Build_Emmres_Agent_Studio_v10.ps1" download>Download PowerShell</a></article><article class="card"><h2>Environment updater</h2><p>Updates the installed environment and regenerates documentation.</p><a class="button" href="../../Update_Installed_Environment.cmd" download>Download updater</a></article><article class="card"><h2>Python dependencies</h2><a class="button" href="../../portable_requirements_v10.txt" download>Download requirements</a></article><article class="card"><h2>Catalog archive</h2><a class="button" href="../../Skills_Catalogs.xml" download>Download catalog archive</a></article></section><h2>Official tool downloads</h2><section class="grid">'''
published_manifest=DOCS/'downloads'/'environment'/'published-files.json'
published=[]
if published_manifest.exists():
    try: published=json.loads(published_manifest.read_text('utf-8-sig')).get('files',[])
    except Exception: published=[]
dl+=f'<article class="card"><h3>Published environment files</h3><p>{len(published)} same-origin, agent-readable files exported from the installed environment.</p><a class="button" href="environment/index.html">Browse published files</a></article>'
dl+='</section>'
# Build same-origin environment file browser.
envdl=DOCS/'downloads'/'environment'; envdl.mkdir(parents=True,exist_ok=True)
by_pub={}
for x in published: by_pub.setdefault(x.get('category','root'),[]).append(x)
blocks=''
for category,files in sorted(by_pub.items()):
    links=''.join(f'<li><a href="../../../resources/{h(x["relativePath"])}" download>{h(x["relativePath"])}</a> <span class="meta">({x["bytes"]:,} bytes)</span></li>' for x in files)
    blocks+=f'<section class="panel"><h2>{h(category)}</h2><ul>{links}</ul></section>'
if not blocks: blocks='<section class="panel"><p>No installed environment files have been published yet. Run <code>Publish_Agent_Knowledge.cmd</code> after installation.</p></section>'
(envdl/'index.html').write_text(page('Published environment files','<h1>Published environment files</h1><p>Resources copied from Local Environment. Readable files are searchable; binary assets such as ONNX are downloadable through Git LFS.</p>'+blocks,2),encoding='utf-8')
(DOCS/'downloads'/'index.html').write_text(page('Downloads',dl,1),encoding='utf-8')

# Landing page contains category navigation only, not one giant compact inventory.
landing=f'''<h1>Emmre's Portable Agent Studio</h1><p>A structured, downloadable knowledge hub for the complete installer, external tools, Python environment, and skill catalogs.</p><section class="grid"><article class="card"><h2>Tools</h2><p>{len(tools)} installer-managed runtimes and command-line tools, organized into {len(bycat)} categories.</p><a href="tools/index.html">Browse tools</a></article><article class="card"><h2>Python environment</h2><p>{sum(len(x[1]) for x in sections)} packages across {len(sections)} capability categories.</p><a href="environment/index.html">Browse environment</a></article><article class="card"><h2>Downloads</h2><p>Installer files, updater, requirements, catalogs, and official upstream downloads.</p><a href="downloads/index.html">Open download center</a></article><article class="card"><h2>Catalogs</h2><p>{len(cat_items)} skill and capability catalogs in a separate searchable area.</p><a href="catalogs/index.html">Browse catalogs</a></article></section><section class="panel"><h2>Agent access</h2><p>Agent Builder can search these public pages and understand what is available. The pages do not give it permission to run tools installed on a private Windows computer.</p><p><a href="catalog.json">Open machine-readable catalog</a></p></section>'''
(DOCS/'index.html').write_text(page("Emmre's Portable Agent Studio",landing,0),encoding='utf-8')
(DOCS/'.nojekyll').write_text('',encoding='ascii')
full={'schemaVersion':'3.0','name':"Emmre's Portable Agent Studio",'pages':{'tools':'tools/index.html','environment':'environment/index.html','downloads':'downloads/index.html','catalogs':'catalogs/index.html'},'tools':[{'category':a,'name':b,'description':c,'installedPath':'Emmres_Environment/'+e} for a,b,c,d,e in tools],'pythonCategories':[{'name':a,'page':'environment/'+slug(a)+'.html','packages':b} for a,b in sections],'installedEnvironment':manifest,'catalogs':cat_items}
(DOCS/'catalog.json').write_text(json.dumps(full,indent=2,ensure_ascii=False),encoding='utf-8')
print(f'Generated {len(tools)} tools, {sum(len(x[1]) for x in sections)} packages, {len(cat_items)} catalogs, {len(sections)} environment categories.')

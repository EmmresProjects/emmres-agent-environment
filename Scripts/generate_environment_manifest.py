from importlib import metadata
from pathlib import Path
import json,sys
repo=Path(sys.argv[1]).resolve(); env=repo.parent/"Local Environment"; vf=env/"logs/verification.tsv"
tools=[]
if vf.exists():
 for raw in vf.read_text("utf-8-sig",errors="replace").splitlines():
  a=raw.split("\t",2); cmd=a[0].strip() if a else ""; code=a[1].strip() if len(a)>1 else ""
  if cmd: tools.append({"name":cmd.split()[0],"verificationCommand":cmd,"exitCode":int(code) if code.isdigit() else code,"installed":code=="0","output":a[2].strip() if len(a)>2 else ""})
pkgs=sorted(({"name":d.metadata.get("Name") or "unknown","version":d.version} for d in metadata.distributions()),key=lambda x:x["name"].lower())
m={"schemaVersion":"2.0","environmentRoot":"../Local Environment","python":{"executable":"../Local Environment/venv/Scripts/python.exe","packages":pkgs},"tools":tools}
t=json.dumps(m,indent=2,ensure_ascii=False); (env/"environment-manifest.json").write_text(t,encoding="utf-8"); (repo/"docs/environment-manifest.json").write_text(t,encoding="utf-8")
print(f"Manifest written with {len(pkgs)} packages and {len(tools)} tool checks.")

#!/usr/bin/env python3
"""Split antigravity-awesome-skills by editorial bundles.md as per-bundle plugin dirs."""
import json, os, re, shutil, sys


def slugify(name):
    return "aas-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def parse_bundles(md_path):
    """Return dict of slug -> [skill, ...] from bundles.md."""
    bundles = {}
    current = None
    with open(md_path) as f:
        for line in f:
            line = line.rstrip()
            # Match: ### emoji The "Web Wizard" Pack
            m = re.match(r'###.*The "(.+?)".*Pack', line)
            if m:
                current = slugify(m.group(1))
                bundles.setdefault(current, [])
            elif current:
                # Match: - [`skill-name`](../../skills/skill-name/): description
                m2 = re.match(r'- \[`(.+?)`\]', line)
                if m2:
                    bundles[current].append(m2.group(1))
    return {k: v for k, v in bundles.items() if v}


def write_plugin(plugin_dir, name, description, skills_src, skill_names):
    skills_dst = os.path.join(plugin_dir, "skills")
    os.makedirs(skills_dst, exist_ok=True)
    missing = []
    for skill in skill_names:
        src = os.path.join(skills_src, skill)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(skills_dst, skill), dirs_exist_ok=True)
        else:
            missing.append(skill)
    if missing:
        print(f"  WARNING: missing skills: {missing}", file=sys.stderr)
    meta_dir = os.path.join(plugin_dir, ".claude-plugin")
    os.makedirs(meta_dir, exist_ok=True)
    with open(os.path.join(meta_dir, "plugin.json"), "w") as f:
        json.dump({"name": name, "description": description}, f, indent=2)


def main():
    if len(sys.argv) != 4:
        print("Usage: install-aas-bundles.py <skills_src_dir> <bundles_md> <output_plugins_dir>")
        sys.exit(1)
    skills_src, bundles_md, output_dir = sys.argv[1:]

    bundles = parse_bundles(bundles_md)
    for slug, skill_names in bundles.items():
        label = slug.removeprefix("aas-").replace("-", " ").title()
        write_plugin(
            os.path.join(output_dir, slug), slug,
            f"Antigravity {label} skills bundle (https://github.com/sickn33/antigravity-awesome-skills)",
            skills_src, skill_names,
        )
        print(f"  {slug}: {len(skill_names)} skills")

    # aas-full: all skills
    all_skills = sorted(
        d for d in os.listdir(skills_src) if os.path.isdir(os.path.join(skills_src, d))
    )
    write_plugin(
        os.path.join(output_dir, "aas-full"), "aas-full",
        "Antigravity full skills library (https://github.com/sickn33/antigravity-awesome-skills/)",
        skills_src, all_skills,
    )
    print(f"  aas-full: {len(all_skills)} skills")


if __name__ == "__main__":
    main()

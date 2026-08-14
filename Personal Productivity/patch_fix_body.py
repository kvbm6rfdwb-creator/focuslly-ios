path = "PipelineTabView.swift"
c = open(path).read()

# The body still has the OLD banner block - patch_discipline.py ran first and patch_bigfour.py ran on the original
# Find and fix the body block
old = (
    "                        // \u2500\u2500 Big Four banner (if not yet done today) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        if !pipeline.bigFourToday.passesRule {\n"
    "                            bigFourBanner\n"
    "                        }\n\n"
    "                        // \u2500\u2500 Primary actions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        primaryActions\n\n"
    "                        // \u2500\u2500 Daily Discipline card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        dailyDisciplineCard"
)
new = (
    "                        // \u2500\u2500 Primary actions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        primaryActions\n\n"
    "                        // \u2500\u2500 Daily Discipline card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        dailyDisciplineCard"
)
if old in c:
    c = c.replace(old, new, 1)
    print("body fixed")
else:
    # Try simpler form - just remove the 3-line if block
    old2 = (
        "                        // \u2500\u2500 Big Four banner (if not yet done today) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
        "                        if !pipeline.bigFourToday.passesRule {\n"
        "                            bigFourBanner\n"
        "                        }\n\n"
    )
    if old2 in c:
        c = c.replace(old2, "", 1)
        print("banner block removed")
    else:
        print("NOT FOUND - trying line search")
        lines = c.split('\n')
        for i,l in enumerate(lines):
            if 'bigFourBanner' in l or 'Big Four banner' in l:
                print(f"  line {i+1}: {repr(l)}")

open(path, "w").write(c)
print("DONE", len(c))

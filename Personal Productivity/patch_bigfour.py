import re

path = "PipelineTabView.swift"
content = open(path).read()

# 1. Remove showBigFour state line
content = content.replace(
    "    @State private var showBigFour       = false\n",
    "", 1)

# 2. Replace the body Big Four banner block + primaryActions
old_body = (
    "                        // \u2500\u2500 Big Four banner (if not yet done today) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        if !pipeline.bigFourToday.passesRule {\n"
    "                            bigFourBanner\n"
    "                        }\n\n"
    "                        // \u2500\u2500 Primary actions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        primaryActions"
)
new_body = (
    "                        // \u2500\u2500 Primary actions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        primaryActions\n\n"
    "                        // \u2500\u2500 Daily Discipline card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "                        dailyDisciplineCard"
)
content = content.replace(old_body, new_body, 1)

# 3. Remove toolbar BigFour button block
old_toolbar = (
    "                ToolbarItem(placement: .topBarTrailing) {\n"
    "                    Button {\n"
    "                        showBigFour = true\n"
    "                    } label: {\n"
    "                        Image(systemName: pipeline.bigFourToday.passesRule ? \"checklist.checked\" : \"checklist\")\n"
    "                            .font(.system(size: 15, weight: .semibold))\n"
    "                            .foregroundStyle(pipeline.bigFourToday.passesRule ? .green : .primary)\n"
    "                    }\n"
    "                }\n"
)
content = content.replace(old_toolbar, "", 1)

# 4. Remove BigFourSheet sheet presentation
old_sheet = (
    "        .sheet(isPresented: $showBigFour) {\n"
    "            BigFourSheet(pipeline: pipeline)\n"
    "        }\n"
)
content = content.replace(old_sheet, "", 1)

open(path, "w").write(content)
print("DONE", len(content))

import json

log_path = "/Users/batudemir/.gemini/antigravity/brain/c10109e8-28ec-43e1-a64c-c6ec830e569f/.system_generated/logs/overview.txt"
output_path = "/Users/batudemir/Desktop/one/one/one/UI/Components/BottomNavigation.swift"

with open(log_path, "r") as f:
    lines = f.readlines()

found = False
content = ""

for line in lines:
    try:
        data = json.loads(line)
        if data.get("step_index") == 552: # response to 551
            content = data.get("content", "")
            break
    except:
        pass

if not content:
    # Try looking for "step_index": 552 or similar
    pass

import re

# Extract the file content from the response text
match = re.search(r"The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>\.(.*?)The above content shows the entire, complete file contents of the requested file\.", content, re.DOTALL)

if match:
    code_lines = match.group(1).strip().split('\n')
    cleaned_code = []
    for cl in code_lines:
        # remove the "123: " prefix
        cl_clean = re.sub(r'^\d+: ', '', cl)
        cleaned_code.append(cl_clean)
        
    with open(output_path, "w") as f:
        f.write('\n'.join(cleaned_code))
    print("Successfully recovered!")
else:
    print("Could not parse the content from the log.")

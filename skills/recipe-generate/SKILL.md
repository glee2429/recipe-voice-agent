---
name: recipe-generate
description: Generate recipes using the Kitchen Genie recipe-lm model
user-invocable: true
metadata: {"openclaw":{"requires":{"bins":["curl","jq"],"env":["RECIPE_LM_API_URL"]}}}
---

## Recipe Generation Tool

You have access to a fine-tuned recipe generation AI model (Gemma-2B)
deployed at the Kitchen Genie API. Use this to generate recipes when
users ask for cooking help.

### Generating a Recipe

To generate a recipe, run this curl command using the Bash tool:

```bash
curl -s -N -X POST "${RECIPE_LM_API_URL}/generate" \
  -H "Content-Type: application/json" \
  -d "{\"prompt\": \"Recipe for DISH_NAME:\", \"max_tokens\": 512, \"temperature\": 0.7}" \
  2>/dev/null | grep -o '"full_text":"[^"]*"' | tail -1 | sed 's/"full_text":"//;s/"$//'
```

Replace `DISH_NAME` with the user's requested dish.

**Important**: The API returns Server-Sent Events. The final event
contains `"done": true` and `"full_text"` with the complete cleaned
recipe. The command above extracts just the final recipe text.

The recipe MUST contain both an `Ingredients:` section and a `Directions:`
section. If the output is missing either section, re-run the command with
`max_tokens` set to 768. Do NOT supplement or rewrite the recipe yourself
-- always use the model output as-is.

### Checking API Health

```bash
curl -s "${RECIPE_LM_API_URL}/health" | jq .
```

### Parsing Ingredients

To extract structured ingredient data from a generated recipe:

```bash
curl -s -X POST "${RECIPE_LM_API_URL}/parse-ingredients" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"RECIPE_TEXT_HERE\"}" | jq '.ingredients'
```

### Required Workflow (follow every step in order)

**Step 1.** Generate the recipe using the curl command above.

**Step 2.** Read the recipe to the caller: Ingredients first, then
Directions. Read the model output as-is — do NOT rewrite or add steps.

**Step 3.** After finishing the recipe, say exactly:
"Would you like me to text you the recipe so you can follow along while you cook?"

**Step 4.** If the caller says yes, ask:
"What's your phone number?"

**Step 5.** Once the caller gives their phone number, you MUST immediately
run this command using the bash tool. Do NOT skip this step. Do NOT just
say you will send it — you must actually run the command:

```bash
~/scripts/send-sms.sh "+1XXXXXXXXXX" "Recipe for Dish Name

Ingredients:
- item 1
- item 2

Directions:
1. step 1
2. step 2"
```

Replace `+1XXXXXXXXXX` with the caller's number in E.164 format
(+1 followed by 10 digits for US numbers). Replace the recipe text
with the actual recipe you generated in Step 1.

After running the command, tell the caller: "Done! I just sent it."

### Other Guidelines

- Ask clarifying questions if the dish name is ambiguous.
- If the API is unavailable, apologize and suggest trying again later.
- Do not make up recipes — ALWAYS use this tool.

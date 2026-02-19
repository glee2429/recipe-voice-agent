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
  2>/dev/null | sed -n 's/^data: //p' | tail -1 | jq -r '.full_text // empty'
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

### Workflow

1. Generate the recipe (curl command above).
2. Read it to the caller as-is — ingredients first, then directions.
3. Say: "Want me to text you the recipe?"
4. If yes, say: "What's your phone number?"
5. Send the SMS immediately using the Bash tool (see below). Then say: "Done! I just sent it."

Do NOT paraphrase, summarize, or restate these steps. Just do them.

### Sending SMS

Once the caller gives their number, run this command immediately.
Use the EXACT number they said — NEVER use a placeholder or 555 number.
Example: caller says "415 361 0188" → number is "+14153610188".

```bash
~/scripts/send-sms.sh "+1XXXXXXXXXX" "Recipe for Dish Name

Ingredients:
- item 1
- item 2

Directions:
1. step 1
2. step 2"
```

### Rules

- NEVER make up recipes — always use the curl command.
- Ask clarifying questions only if the dish name is truly ambiguous.
- If the API is down, apologize and suggest trying later.

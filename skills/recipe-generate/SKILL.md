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

To generate a recipe, run this curl command using the exec tool:

```bash
curl -s -N -X POST "${RECIPE_LM_API_URL}/generate" \
  -H "Content-Type: application/json" \
  -d "{\"prompt\": \"Recipe for DISH_NAME:\", \"max_tokens\": 256, \"temperature\": 0.7}" \
  2>/dev/null | grep -o '"full_text":"[^"]*"' | tail -1 | sed 's/"full_text":"//;s/"$//'
```

Replace `DISH_NAME` with the user's requested dish.

**Important**: The API returns Server-Sent Events. The final event
contains `"done": true` and `"full_text"` with the complete cleaned
recipe. The command above extracts just the final recipe text.

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

### Usage Guidelines

1. When a user asks to cook something, ALWAYS use this tool to generate
   the recipe. Do not make up recipes from your training data.
2. Format the response for voice: read ingredients as a list, then
   directions step by step.
3. Ask clarifying questions if the dish name is ambiguous.
4. If the API is unavailable, apologize and suggest trying again later.
5. Keep responses concise -- voice callers do not want lengthy text.

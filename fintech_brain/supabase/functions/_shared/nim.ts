// NVIDIA NIM client — OpenAI-compatible chat completions API.
// Free API keys: https://build.nvidia.com (sign in, pick a model, "Get API Key")
//
// Set these as Supabase Edge Function secrets:
//   supabase secrets set NVIDIA_NIM_API_KEY=nvapi-xxxxxxxxxxxx
//   supabase secrets set NVIDIA_NIM_MODEL=meta/llama-3.1-8b-instruct

const NIM_URL = "https://integrate.api.nvidia.com/v1/chat/completions";

export interface NimOptions {
  temperature?: number;
  maxTokens?: number;
}

export async function callNim(
  prompt: string,
  opts: NimOptions = {},
): Promise<string> {
  const apiKey = Deno.env.get("NVIDIA_NIM_API_KEY");
  const model = Deno.env.get("NVIDIA_NIM_MODEL") ?? "meta/llama-3.1-8b-instruct";

  if (!apiKey) {
    throw new Error("NVIDIA_NIM_API_KEY secret is not set");
  }

  const resp = await fetch(NIM_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: prompt }],
      temperature: opts.temperature ?? 0.6,
      max_tokens: opts.maxTokens ?? 500,
      stream: false,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`NVIDIA NIM ${resp.status}: ${text.slice(0, 300)}`);
  }

  const data = await resp.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("NVIDIA NIM: unexpected response shape");
  }
  return content.trim();
}

// Strips ```json fences and other markdown noise the model sometimes adds.
export function cleanJson(raw: string): string {
  return raw.replace(/```json\s*|```\s*/g, "").trim();
}

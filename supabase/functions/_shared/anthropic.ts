// Anthropic API proxy helper. The API key lives only in Supabase secrets;
// it never ships in the iOS app. Strict JSON output is enforced by forcing a
// single tool call whose input_schema is the desired shape (strict: true), so
// the response validates against the schema at the API layer.
import Anthropic from 'npm:@anthropic-ai/sdk@^0.88.0';

// Spec section 4 names Claude Sonnet for both vision and generation.
const DEFAULT_MODEL = 'claude-sonnet-5';

export type ImageInput = {
  data: string; // base64, no newlines
  mediaType: 'image/jpeg' | 'image/png';
};

export type ToolCallOptions = {
  system: string;
  userText: string;
  images?: ImageInput[];
  toolName: string;
  toolDescription: string;
  schema: Record<string, unknown>; // JSON Schema, additionalProperties: false throughout
  maxTokens?: number;
  // Extraction tasks (scan) run with thinking disabled for speed and cost;
  // generation keeps adaptive thinking for better constraint satisfaction.
  thinking?: 'adaptive' | 'disabled';
};

const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') ?? '' });

export async function callClaudeTool(opts: ToolCallOptions): Promise<Record<string, unknown>> {
  const model = Deno.env.get('ANTHROPIC_MODEL') ?? DEFAULT_MODEL;

  const content: Anthropic.ContentBlockParam[] = [];
  for (const image of opts.images ?? []) {
    content.push({
      type: 'image',
      source: { type: 'base64', media_type: image.mediaType, data: image.data },
    });
  }
  content.push({ type: 'text', text: opts.userText });

  const response = await client.messages.create({
    model,
    max_tokens: opts.maxTokens ?? 4096,
    system: opts.system,
    thinking: opts.thinking === 'disabled' ? { type: 'disabled' } : { type: 'adaptive' },
    tools: [
      {
        name: opts.toolName,
        description: opts.toolDescription,
        strict: true,
        input_schema: opts.schema as Anthropic.Tool.InputSchema,
      },
    ],
    tool_choice: { type: 'tool', name: opts.toolName },
    messages: [{ role: 'user', content }],
  });

  if (response.stop_reason === 'refusal') {
    throw new AnthropicToolError('The request was declined. Try different photos.', 422);
  }

  const toolUse = response.content.find(
    (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use',
  );
  if (!toolUse) {
    if (response.stop_reason === 'max_tokens') {
      throw new AnthropicToolError('Response was truncated. Please retry.', 502);
    }
    throw new AnthropicToolError('Model returned no structured result. Please retry.', 502);
  }
  return toolUse.input as Record<string, unknown>;
}

export class AnthropicToolError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

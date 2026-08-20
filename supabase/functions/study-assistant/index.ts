import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const cardSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['type', 'prompt', 'answer', 'options', 'explanation'],
  properties: {
    type: {
      type: 'string',
      enum: ['qa', 'multiple_choice', 'true_false'],
    },
    prompt: { type: 'string' },
    answer: { type: 'string' },
    options: {
      type: 'array',
      items: { type: 'string' },
    },
    explanation: { type: 'string' },
  },
};

const lessonSectionSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['title', 'body', 'example'],
  properties: {
    title: { type: 'string' },
    body: { type: 'string' },
    example: { anyOf: [{ type: 'string' }, { type: 'null' }] },
  },
};

const lessonSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['title', 'sections', 'takeaway'],
  properties: {
    title: { type: 'string' },
    sections: {
      type: 'array',
      items: lessonSectionSchema,
    },
    takeaway: { anyOf: [{ type: 'string' }, { type: 'null' }] },
  },
};

const checkpointSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['prompt', 'options', 'hint', 'expectedAnswer'],
  properties: {
    prompt: { type: 'string' },
    options: {
      type: 'array',
      items: { type: 'string' },
    },
    hint: { anyOf: [{ type: 'string' }, { type: 'null' }] },
    expectedAnswer: { anyOf: [{ type: 'string' }, { type: 'null' }] },
  },
};

const responseSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'phase',
    'message',
    'nextActions',
    'lesson',
    'checkpoint',
    'feedback',
    'shouldAskFollowUp',
    'shouldPersistArtifact',
    'artifact',
  ],
  properties: {
    phase: {
      type: 'string',
      enum: [
        'intake',
        'level_check',
        'lesson',
        'checkpoint',
        'feedback',
        'guided_practice',
        'content_confirmation',
        'artifact_generation',
        'review',
      ],
    },
    message: { type: 'string' },
    nextActions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'label', 'description'],
        properties: {
          id: { type: 'string' },
          label: { type: 'string' },
          description: { type: 'string' },
        },
      },
    },
    lesson: {
      anyOf: [{ type: 'null' }, lessonSchema],
    },
    checkpoint: {
      anyOf: [{ type: 'null' }, checkpointSchema],
    },
    feedback: { anyOf: [{ type: 'string' }, { type: 'null' }] },
    shouldAskFollowUp: { type: 'boolean' },
    shouldPersistArtifact: { type: 'boolean' },
    artifact: {
      anyOf: [
        { type: 'null' },
        {
          type: 'object',
          additionalProperties: false,
          required: ['kind', 'title', 'topic', 'summary', 'payload'],
          properties: {
            kind: {
              type: 'string',
              enum: ['flashcards', 'quiz', 'topic_map', 'study_plan'],
            },
            title: { type: 'string' },
            topic: { type: 'string' },
            summary: { type: 'string' },
            payload: {
              type: 'object',
              additionalProperties: false,
              required: ['cards'],
              properties: {
                cards: {
                  type: 'array',
                  items: cardSchema,
                },
              },
            },
          },
        },
      ],
    },
  },
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return json({ error: 'missing_authorization' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey =
    Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  const geminiKey = Deno.env.get('GEMINI_API_KEY');
  const model = (Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.5-flash-lite').replace(
    /^models\//,
    '',
  );
  if (!supabaseUrl || !publishableKey || !geminiKey) {
    return json({ error: 'assistant_not_configured' }, 503);
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: 'invalid_session' }, 401);
  }

  let body: {
    messages?: unknown[];
    topic?: string;
    sourceText?: string;
    phase?: string;
  };
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'invalid_json' }, 400);
  }

  const messages = Array.isArray(body.messages) ? body.messages : [];
  const topic = typeof body.topic === 'string' ? body.topic : '';
  const sourceText = typeof body.sourceText === 'string' ? body.sourceText : '';
  const phase = typeof body.phase === 'string' ? body.phase : 'intake';
  const systemInstruction = [
    'You are FlashCard AI, a patient Turkish tutor and learning-workspace guide.',
    'Always respond in Turkish. Every message, lesson section, checkpoint, feedback, action label, and action description must be in natural Turkish. Never answer in English unless the learner explicitly asks for English.',
    'Your job is to teach, diagnose understanding, and adapt difficulty—not to immediately manufacture flashcard sets.',
    'Return only the supplied JSON schema. Keep nextActions to at most three short, concrete choices.',
    'The first user topic message must produce no artifact. Ask one meaningful follow-up about goal, level, prior knowledge, time, or exam context.',
    'Move through these phases deliberately: intake, level_check, lesson, checkpoint, feedback, guided_practice, content_confirmation, artifact_generation, review.',
    'Ask only one high-value question at a time. Do not turn every user message into a new artifact.',
    'Use lesson when the user needs teaching: give a clear title, two to four structured sections, a practical example, and one takeaway.',
    'After a lesson, use one checkpoint question in chat and wait for the user answer. Evaluate it in a later feedback turn before increasing difficulty.',
    'If the user is confused or wrong, explain the same idea with a different example instead of generating more content.',
    'Only set shouldPersistArtifact=true and return an artifact after the user explicitly requests or confirms a study set, quiz, map, or plan and enough context is known.',
    'Never create multiple artifacts in one turn. Never create a three- or five-question final set by default; use short checks for diagnosis and reserve real study sets for an agreed learning plan.',
    'Whenever artifact is not null, payload.cards is mandatory and must contain concrete, non-repeating study cards. Never return an empty cards array for a generated artifact.',
    'For multiple_choice cards, provide four plausible options and put the correct answer in answer. For qa and true_false cards, provide a specific answer and explanation grounded in the current topic or source.',
    'Do not invent official exam answers. When source text is provided, stay grounded in it and mention uncertainty.',
    `Current learning phase: ${phase}`,
    topic ? `Current topic: ${topic}` : '',
    sourceText ? `Source text:\n${sourceText.slice(0, 30000)}` : '',
  ].filter(Boolean).join('\n\n');

  const contents = messages
    .slice(-24)
    .filter((message): message is { role: string; content: string } => {
      if (typeof message !== 'object' || message === null) return false;
      const candidate = message as { role?: unknown; content?: unknown };
      return (
        (candidate.role === 'user' || candidate.role === 'assistant') &&
        typeof candidate.content === 'string' &&
        candidate.content.trim().length > 0
      );
    })
    .map((message) => ({
      role: message.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: message.content }],
    }));

  // Gemini conversation contents must begin with a user turn. The local store
  // seeds the UI with an assistant greeting, so discard leading model turns.
  while (contents[0]?.role === 'model') contents.shift();
  if (contents.length === 0) return json({ error: 'empty_conversation' }, 400);

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
    {
      method: 'POST',
      headers: {
        'x-goog-api-key': geminiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemInstruction }],
        },
        contents,
        generationConfig: {
          responseMimeType: 'application/json',
          responseJsonSchema: responseSchema,
          temperature: 0.35,
          maxOutputTokens: 4096,
        },
      }),
    },
  );

  if (!response.ok) {
    const providerError = (await response.text()).slice(0, 1200);
    console.error('Gemini request failed', {
      status: response.status,
      body: providerError,
    });
    return json(
      {
        error: 'model_request_failed',
        upstreamStatus: response.status,
        detail: providerError,
      },
      502,
    );
  }

  const result = await response.json();
  const outputText = result.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part.text ?? '')
    ?.join('')
    ?.trim();
  if (typeof outputText !== 'string') {
    return json({ error: 'empty_model_response' }, 502);
  }

  try {
    const parsed = JSON.parse(outputText) as Record<string, unknown>;
    const latestUserMessage = [...messages]
      .reverse()
      .find(
        (message) =>
          typeof message === 'object' &&
          message !== null &&
          (message as { role?: unknown }).role === 'user',
      ) as { content?: unknown } | undefined;
    const latestUserText =
      typeof latestUserMessage?.content === 'string'
        ? latestUserMessage.content
        : '';
    const explicitArtifactIntent =
      /flashcard|kart|quiz|test|soru seti|konu haritası|çalışma planı|hazırla|oluştur|üret/i.test(
        latestUserText,
      );
    if (!explicitArtifactIntent || parsed.shouldPersistArtifact !== true) {
      parsed.shouldPersistArtifact = false;
      parsed.artifact = null;
    }
    return json(parsed);
  } catch (_) {
    return json({ error: 'invalid_model_json' }, 502);
  }
});

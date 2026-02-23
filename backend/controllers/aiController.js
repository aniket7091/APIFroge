const axios = require('axios');
const History = require('../models/History');

/**
 * POST /api/ai/execute
 * Sends prompt to Groq API, parses structured JSON, and executes the HTTP request.
 *
 * Body: { prompt, context: { envVars, collections, ... } }
 */
const executeAiTask = async (req, res, next) => {
    try {
        const { prompt, context } = req.body;

        if (!prompt) {
            return res.status(400).json({ success: false, message: 'Prompt is required' });
        }

        const apiKey = process.env.GROQ_API_KEY;
        if (!apiKey) {
            return res.status(500).json({ success: false, message: 'GROQ_API_KEY is not configured in the server' });
        }

        // 1. Construct System Prompt
        const systemPrompt = `You are an AI API assistant for an application called APIForge.
Your task is to convert the user's natural language request into a valid HTTP request configuration.
You must return your response STRICTLY as a JSON object with the following schema, and NO markdown wrapping or other text:
{
  "method": "GET|POST|PUT|PATCH|DELETE",
  "url": "full URL string",
  "headers": { "key": "value" },
  "params": { "key": "value" },
  "body": {} or null
}

Available Context (Environment variables, etc):
${JSON.stringify(context || {}, null, 2)}

Make sure to substitute environment variables like {{BASE_URL}} if they are provided in context, or leave them as is if not.
If the user specifies payload data, place it in the "body" field appropriately.
If it's a GET or DELETE request, body should usually be null. Everything else depends on the prompt.`;

        // 2. Call Groq API strictly for JSON response
        const groqResponse = await axios.post(
            'https://api.groq.com/openai/v1/chat/completions',
            {
                model: 'moonshotai/kimi-k2-instruct-0905',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.1, // Low temperature for deterministic JSON output
                response_format: { type: 'json_object' } // Enforce JSON
            },
            {
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        const aiMessageContent = groqResponse.data.choices[0].message.content;
        let aiRequestConfig;

        try {
            aiRequestConfig = JSON.parse(aiMessageContent);
        } catch (parseError) {
            return res.status(500).json({
                success: false,
                message: 'Failed to parse AI response into JSON format',
                rawResponse: aiMessageContent
            });
        }

        // Validate basic fields
        if (!aiRequestConfig.method || !aiRequestConfig.url) {
            return res.status(500).json({
                success: false,
                message: 'AI generated invalid request config (missing method or url)',
                aiRequestConfig
            });
        }

        // 3. Execute the Request
        // We simulate the logic of proxyController's proxy call here
        const startTime = Date.now();
        let historyEntry = {
            userId: req.user._id,
            method: aiRequestConfig.method.toUpperCase(),
            url: aiRequestConfig.url,
            requestHeaders: aiRequestConfig.headers || {},
            requestBody: aiRequestConfig.body || null,
            isError: false,
        };

        let proxyResponse;
        let responseTime;

        try {
            const axiosConfig = {
                method: aiRequestConfig.method.toUpperCase(),
                url: aiRequestConfig.url,
                headers: aiRequestConfig.headers || {},
                params: aiRequestConfig.params || {},
                data: ['POST', 'PUT', 'PATCH'].includes(aiRequestConfig.method.toUpperCase()) ? aiRequestConfig.body : undefined,
                timeout: 30000,
                validateStatus: () => true, // resolve on all status codes
            };

            const axRes = await axios(axiosConfig);
            responseTime = Date.now() - startTime;

            proxyResponse = {
                statusCode: axRes.status,
                statusText: axRes.statusText,
                headers: axRes.headers,
                body: axRes.data,
                responseTime,
                size: JSON.stringify(axRes.data || "").length,
                isError: false
            };

            historyEntry = {
                ...historyEntry,
                statusCode: axRes.status,
                responseHeaders: axRes.headers,
                responseBody: axRes.data,
                responseTime,
            };
            await History.create(historyEntry);

        } catch (proxyError) {
            responseTime = Date.now() - startTime;
            proxyResponse = {
                statusCode: 0,
                statusText: 'Request Failed',
                headers: {},
                body: null,
                responseTime,
                isError: true,
                errorMessage: proxyError.message,
            };

            historyEntry = {
                ...historyEntry,
                isError: true,
                errorMessage: proxyError.message,
                responseTime,
            };
            await History.create(historyEntry).catch(() => { });
        }

        // 4. Return combined result to client
        return res.json({
            success: true,
            data: {
                aiRequest: aiRequestConfig,
                proxyResponse: proxyResponse
            }
        });

    } catch (error) {
        // Handle global errors, e.g. Groq limits or network issues
        console.error('AI execution error:', error.response?.data || error.message);
        next(error);
    }
};

module.exports = { executeAiTask };

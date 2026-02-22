const axios = require('axios');
const History = require('../models/History');

/**
 * POST /api/proxy/send
 * Core proxy: forwards the user's HTTP request through Axios,
 * captures the response, saves to History, and returns result.
 *
 * Body: { method, url, headers, params, body, bodyType, auth }
 */
const sendRequest = async (req, res, next) => {
    const { method, url, headers = {}, params = {}, body, bodyType, auth } = req.body;

    if (!method || !url) {
        return res.status(400).json({ success: false, message: 'method and url are required' });
    }

    const startTime = Date.now();
    let historyEntry = {
        userId: req.user._id,
        method: method.toUpperCase(),
        url,
        requestHeaders: headers,
        requestBody: body || null,
        isError: false,
    };

    try {
        // Build Authorization header from auth config
        const finalHeaders = { ...headers };
        if (auth) {
            if (auth.type === 'bearer' && auth.token) {
                finalHeaders['Authorization'] = `Bearer ${auth.token}`;
            } else if (auth.type === 'basic' && auth.username) {
                const encoded = Buffer.from(`${auth.username}:${auth.password}`).toString('base64');
                finalHeaders['Authorization'] = `Basic ${encoded}`;
            }
        }

        // Build Axios config
        const axiosConfig = {
            method: method.toUpperCase(),
            url,
            headers: finalHeaders,
            params,
            // Only send body for methods that support it
            data: ['POST', 'PUT', 'PATCH'].includes(method.toUpperCase()) ? body : undefined,
            timeout: 30000,
            validateStatus: () => true, // don't throw on non-2xx
        };

        const response = await axios(axiosConfig);
        const responseTime = Date.now() - startTime;

        // Save to history
        historyEntry = {
            ...historyEntry,
            statusCode: response.status,
            responseHeaders: response.headers,
            responseBody: response.data,
            responseTime,
        };
        await History.create(historyEntry);

        res.json({
            success: true,
            data: {
                statusCode: response.status,
                statusText: response.statusText,
                headers: response.headers,
                body: response.data,
                responseTime,
                size: JSON.stringify(response.data).length,
            },
        });
    } catch (error) {
        const responseTime = Date.now() - startTime;
        historyEntry = {
            ...historyEntry,
            isError: true,
            errorMessage: error.message,
            responseTime,
        };
        await History.create(historyEntry).catch(() => { }); // best-effort save

        res.status(500).json({
            success: false,
            message: error.message,
            data: {
                statusCode: 0,
                statusText: 'Request Failed',
                headers: {},
                body: null,
                responseTime,
                isError: true,
                errorMessage: error.message,
            },
        });
    }
};

/**
 * POST /api/proxy/run-performance
 * Runs the same request N times and returns aggregate stats.
 *
 * Body: { method, url, headers, params, body, auth, iterations }
 */
const runPerformanceTest = async (req, res, next) => {
    const { method, url, headers = {}, params = {}, body, auth, iterations = 10 } = req.body;

    if (!method || !url) {
        return res.status(400).json({ success: false, message: 'method and url are required' });
    }

    const count = Math.min(Math.max(parseInt(iterations), 1), 100); // clamp 1-100
    const results = [];

    const finalHeaders = { ...headers };
    if (auth?.type === 'bearer' && auth.token) {
        finalHeaders['Authorization'] = `Bearer ${auth.token}`;
    }

    for (let i = 0; i < count; i++) {
        const t = Date.now();
        try {
            const r = await axios({
                method: method.toUpperCase(),
                url,
                headers: finalHeaders,
                params,
                data: ['POST', 'PUT', 'PATCH'].includes(method.toUpperCase()) ? body : undefined,
                timeout: 15000,
                validateStatus: () => true,
            });
            results.push({ iteration: i + 1, statusCode: r.status, responseTime: Date.now() - t, success: true });
        } catch (e) {
            results.push({ iteration: i + 1, statusCode: 0, responseTime: Date.now() - t, success: false, error: e.message });
        }
    }

    const times = results.map((r) => r.responseTime);
    const avg = times.reduce((a, b) => a + b, 0) / times.length;
    const min = Math.min(...times);
    const max = Math.max(...times);
    const successCount = results.filter((r) => r.success).length;

    res.json({
        success: true,
        data: {
            results,
            summary: {
                iterations: count,
                successRate: `${Math.round((successCount / count) * 100)}%`,
                avgResponseTime: Math.round(avg),
                minResponseTime: min,
                maxResponseTime: max,
            },
        },
    });
};

module.exports = { sendRequest, runPerformanceTest };

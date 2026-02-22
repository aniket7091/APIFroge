/**
 * Snippet Generator Service
 * Converts a request config into curl and JavaScript fetch code snippets.
 */

/**
 * Generate a curl command string.
 * @param {Object} config - { method, url, headers, params, body, auth }
 * @returns {string}
 */
const generateCurl = ({ method = 'GET', url, headers = {}, params = {}, body, auth }) => {
    const lines = [`curl -X ${method.toUpperCase()} '${buildUrl(url, params)}'`];

    // Auth header
    const allHeaders = buildHeaders(headers, auth);
    for (const [k, v] of Object.entries(allHeaders)) {
        lines.push(`  -H '${k}: ${v}'`);
    }

    // Body
    if (body && ['POST', 'PUT', 'PATCH'].includes(method.toUpperCase())) {
        const bodyStr = typeof body === 'string' ? body : JSON.stringify(body);
        lines.push(`  -H 'Content-Type: application/json'`);
        lines.push(`  -d '${bodyStr}'`);
    }

    return lines.join(' \\\n');
};

/**
 * Generate a JavaScript fetch snippet.
 * @param {Object} config
 * @returns {string}
 */
const generateJsFetch = ({ method = 'GET', url, headers = {}, params = {}, body, auth }) => {
    const allHeaders = buildHeaders(headers, auth);
    const hasBody = body && ['POST', 'PUT', 'PATCH'].includes(method.toUpperCase());
    if (hasBody) allHeaders['Content-Type'] = 'application/json';

    const opts = {
        method: method.toUpperCase(),
        headers: allHeaders,
        ...(hasBody ? { body: JSON.stringify(body) } : {}),
    };

    return `const response = await fetch('${buildUrl(url, params)}', ${JSON.stringify(opts, null, 2)});
const data = await response.json();
console.log(data);`;
};

/**
 * Append query params to a URL string.
 */
const buildUrl = (url, params = {}) => {
    const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== '');
    if (!entries.length) return url;
    const qs = entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
    return `${url}${url.includes('?') ? '&' : '?'}${qs}`;
};

/**
 * Merge custom headers with auth header.
 */
const buildHeaders = (headers = {}, auth) => {
    const h = { ...headers };
    if (auth?.type === 'bearer' && auth.token) {
        h['Authorization'] = `Bearer ${auth.token}`;
    } else if (auth?.type === 'basic' && auth.username) {
        const encoded = Buffer.from(`${auth.username}:${auth.password}`).toString('base64');
        h['Authorization'] = `Basic ${encoded}`;
    }
    return h;
};

module.exports = { generateCurl, generateJsFetch };

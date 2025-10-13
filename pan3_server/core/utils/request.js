// /www/wwwroot/pan3/core/utils/request.js

// 固定的JAC API基础地址
export const baseApiUrl = 'https://jacsupperapp.jac.com.cn';

/**
 * 一个通用的网络请求函数
 * @param {string} url - 请求的URL
 * @param {object} data - 发送的JSON数据
 * @param {object} additionalHeaders - 额外的请求头
 * @returns {Promise<object>} - 返回解析后的JSON数据
 */
export async function makeRequest(url, data, additionalHeaders = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...additionalHeaders,
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: headers,
    body: JSON.stringify(data),
    timeout: 30000,
  });

  const responseText = await response.text();

  if (!response.ok) {
    console.error(`HTTP请求失败，状态码: ${response.status}，响应: ${responseText.substring(0, 200)}`);
    throw new Error(`HTTP error: ${response.status}`);
  }

  try {
    return JSON.parse(responseText);
  } catch (e) {
    console.error(`响应JSON解析失败: ${e.message}，响应前200字符: ${responseText.substring(0, 200)}`);
    throw new Error('Response JSON decode error');
  }
}
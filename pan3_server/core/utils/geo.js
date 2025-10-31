// /www/wwwroot/pan3/core/utils/geo.js

/**
 * 将角度转换为弧度
 * @param {number} degrees - 角度
 * @returns {number} 弧度
 */
function toRad(degrees) {
    return degrees * (Math.PI / 180);
}

/**
 * 使用 Haversine 公式计算两个经纬度之间的距离
 * @param {number} lat1 - 起点纬度
 * @param {number} lon1 - 起点经度
 * @param {number} lat2 - 终点纬度
 * @param {number} lon2 - 终点经度
 * @returns {number} 距离（公里）
 */
export function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // 地球半径（公里）
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

/**
 * 计算速度
 * @param {number} lat1 - 起点纬度
 * @param {number} lon1 - 起点经度
 * @param {number} timestamp1 - 起点时间戳（毫秒）
 * @param {number} lat2 - 终点纬度
 * @param {number} lon2 - 终点经度
 * @param {number} timestamp2 - 终点时间戳（毫秒）
 * @returns {number} 速度（km/h），如果时间差为 0 则返回 0
 */
export function calculateSpeed(lat1, lon1, timestamp1, lat2, lon2, timestamp2) {
    const distance = calculateDistance(lat1, lon1, lat2, lon2);
    const timeHours = (timestamp2 - timestamp1) / (1000 * 60 * 60);
    return timeHours > 0 ? Math.round(distance / timeHours) : 0;
}


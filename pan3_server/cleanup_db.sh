#!/bin/bash

# SQLite数据库清理脚本
# 作用：清理数据库碎片，释放已删除数据占用的空间
# 使用方法：./cleanup_db.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 数据库文件路径
DB_FILE="pan3_data.db"

# 检查数据库文件是否存在
if [ ! -f "$DB_FILE" ]; then
    echo -e "${RED}❌ 错误: 找不到数据库文件 $DB_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}   SQLite 数据库清理工具${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# 获取清理前的信息
echo -e "${YELLOW}📊 清理前状态:${NC}"
BEFORE_SIZE=$(ls -lh "$DB_FILE" | awk '{print $5}')
echo -e "  文件大小: ${YELLOW}$BEFORE_SIZE${NC}"

# 获取数据库统计信息
sqlite3 "$DB_FILE" << 'EOF' > /tmp/db_stats_before.txt
.mode column
SELECT 'vehicles' as 表名, COUNT(*) as 记录数 FROM vehicles
UNION ALL
SELECT 'drives', COUNT(*) FROM drives
UNION ALL
SELECT 'charges', COUNT(*) FROM charges
UNION ALL
SELECT 'charge_tasks', COUNT(*) FROM charge_tasks
UNION ALL
SELECT 'data_points', COUNT(*) FROM data_points;
EOF

cat /tmp/db_stats_before.txt
echo ""

# 获取页面信息
PAGE_INFO=$(sqlite3 "$DB_FILE" "PRAGMA page_size; PRAGMA page_count; PRAGMA freelist_count;")
PAGE_SIZE=$(echo "$PAGE_INFO" | sed -n '1p')
PAGE_COUNT=$(echo "$PAGE_INFO" | sed -n '2p')
FREELIST_COUNT=$(echo "$PAGE_INFO" | sed -n '3p')

TOTAL_SIZE=$((PAGE_SIZE * PAGE_COUNT / 1024))
FREE_SIZE=$((PAGE_SIZE * FREELIST_COUNT / 1024))
USED_SIZE=$((TOTAL_SIZE - FREE_SIZE))
USED_PAGES=$((PAGE_COUNT - FREELIST_COUNT))

echo -e "  总页数: ${PAGE_COUNT}页 (${TOTAL_SIZE}KB)"
echo -e "  空闲页: ${RED}${FREELIST_COUNT}页 (${FREE_SIZE}KB)${NC} ← 可释放的空间"
echo -e "  使用页: ${USED_PAGES}页 (${USED_SIZE}KB)"
echo ""

# 询问是否继续
if [ "$FREELIST_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ 数据库很健康，没有需要清理的碎片空间！${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  发现 ${FREELIST_COUNT} 个空闲页面 (约${FREE_SIZE}KB)${NC}"
echo -e "是否执行清理? (y/n)"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${BLUE}已取消清理操作${NC}"
    exit 0
fi

# 执行清理
echo ""
echo -e "${GREEN}🔧 开始清理...${NC}"

# 1. WAL Checkpoint
echo -e "  [1/3] 执行 WAL Checkpoint..."
sqlite3 "$DB_FILE" "PRAGMA wal_checkpoint(TRUNCATE);" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Checkpoint 完成"
else
    echo -e "  ${RED}✗${NC} Checkpoint 失败"
fi

# 2. VACUUM
echo -e "  [2/3] 执行 VACUUM (清理碎片)..."
sqlite3 "$DB_FILE" "VACUUM;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} VACUUM 完成"
else
    echo -e "  ${RED}✗${NC} VACUUM 失败"
    exit 1
fi

# 3. ANALYZE (优化查询性能)
echo -e "  [3/3] 执行 ANALYZE (优化索引)..."
sqlite3 "$DB_FILE" "ANALYZE;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} ANALYZE 完成"
else
    echo -e "  ${YELLOW}⚠${NC} ANALYZE 失败 (不影响清理结果)"
fi

echo ""

# 获取清理后的信息
echo -e "${GREEN}📊 清理后状态:${NC}"
AFTER_SIZE=$(ls -lh "$DB_FILE" | awk '{print $5}')
echo -e "  文件大小: ${GREEN}$AFTER_SIZE${NC}"

# 重新获取页面信息
PAGE_INFO_AFTER=$(sqlite3 "$DB_FILE" "PRAGMA page_size; PRAGMA page_count; PRAGMA freelist_count;")
PAGE_COUNT_AFTER=$(echo "$PAGE_INFO_AFTER" | sed -n '2p')
FREELIST_COUNT_AFTER=$(echo "$PAGE_INFO_AFTER" | sed -n '3p')

TOTAL_SIZE_AFTER=$((PAGE_SIZE * PAGE_COUNT_AFTER / 1024))
FREE_SIZE_AFTER=$((PAGE_SIZE * FREELIST_COUNT_AFTER / 1024))

echo -e "  总页数: ${PAGE_COUNT_AFTER}页 (${TOTAL_SIZE_AFTER}KB)"
echo -e "  空闲页: ${GREEN}${FREELIST_COUNT_AFTER}页 (${FREE_SIZE_AFTER}KB)${NC}"
echo ""

# 计算节省的空间
SAVED_KB=$((TOTAL_SIZE - TOTAL_SIZE_AFTER))
if [ $SAVED_KB -gt 0 ]; then
    echo -e "${GREEN}✨ 清理完成！节省了 ${SAVED_KB}KB 空间${NC}"
else
    echo -e "${YELLOW}⚠️  清理完成，但未能释放空间（数据库可能正在使用中）${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✓ 数据库优化完成！${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"

# 清理临时文件
rm -f /tmp/db_stats_before.txt


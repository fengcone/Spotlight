#!/bin/bash

echo "🧪 Running Spotlight Tests..."
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 创建测试报告目录
mkdir -p Tests/Reports

# 检查是否有 Xcode 项目
if [ ! -d "Spotlight.xcodeproj" ]; then
    echo "${YELLOW}⚠️  Xcode 项目不存在，正在创建...${NC}"
    echo "请使用 Xcode 打开并创建项目，或使用以下命令:"
    echo "  xcodebuild -project Spotlight.xcodeproj"
    exit 1
fi

# 运行单元测试
echo "${YELLOW}📦 Running Unit Tests...${NC}"
echo ""

xcodebuild test \
    -project Spotlight.xcodeproj \
    -scheme Spotlight \
    -destination 'platform=macOS' \
    -only-testing:SpotlightTests/ConfigManagerTests \
    -only-testing:SpotlightTests/SearchEngineTests \
    -only-testing:SpotlightTests/GlobalHotKeyMonitorTests \
    -enableCodeCoverage YES \
    | tee Tests/Reports/unit-tests.log

UNIT_TEST_RESULT=$?

# 运行 E2E 测试
echo ""
echo "${YELLOW}🔄 Running E2E Tests...${NC}"
echo ""

xcodebuild test \
    -project Spotlight.xcodeproj \
    -scheme Spotlight \
    -destination 'platform=macOS' \
    -only-testing:SpotlightTests/SpotlightE2ETests \
    | tee Tests/Reports/e2e-tests.log

E2E_TEST_RESULT=$?

# 生成覆盖率报告
echo ""
echo "${YELLOW}📊 Generating Coverage Report...${NC}"
echo ""

# 这里需要实际的 .xcresult 路径
# xcrun xccov view --report path/to/Test.xcresult > Tests/Reports/coverage.html

# 总结结果
echo ""
echo "========================================"
echo "           TEST SUMMARY"
echo "========================================"

if [ $UNIT_TEST_RESULT -eq 0 ]; then
    echo "${GREEN}✅ Unit Tests: PASSED${NC}"
else
    echo "${RED}❌ Unit Tests: FAILED${NC}"
fi

if [ $E2E_TEST_RESULT -eq 0 ]; then
    echo "${GREEN}✅ E2E Tests: PASSED${NC}"
else
    echo "${RED}❌ E2E Tests: FAILED${NC}"
fi

echo "========================================"
echo ""

# 显示报告位置
echo "📄 Test reports saved to: Tests/Reports/"
echo ""

# 退出码
if [ $UNIT_TEST_RESULT -eq 0 ] && [ $E2E_TEST_RESULT -eq 0 ]; then
    echo "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo "${RED}⚠️  Some tests failed. Please check the logs.${NC}"
    exit 1
fi

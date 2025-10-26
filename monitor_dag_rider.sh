#!/bin/bash

# DAG-Rider 监控脚本
# 此脚本用于监控系统运行状态和显示关键信息

echo "📊 DAG-Rider 系统监控"
echo "====================="

# 检查节点进程
echo "🔧 节点状态："
for i in {1..4}; do
    if [ -f "logs/node$i.pid" ]; then
        pid=$(cat "logs/node$i.pid")
        if ps -p $pid > /dev/null 2>&1; then
            echo "   ✅ 节点$i: 运行中 (PID: $pid)"
        else
            echo "   ❌ 节点$i: 已停止"
        fi
    else
        echo "   ❓ 节点$i: 状态未知"
    fi
done

echo ""

# 检查端口监听
echo "🔍 端口监听状态："
for port in 1234 1235 1236 1237; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "   ✅ 端口 $port: 正在监听"
    else
        echo "   ❌ 端口 $port: 未监听"
    fi
done

echo ""

# 显示最近的共识活动
echo "📋 最近的共识活动："
echo "-------------------"

if [ -f "logs/node1.log" ]; then
    echo "节点1 (领导者选举和排序):"
    tail -10 logs/node1.log | grep -E "(Vertex committed|DAG has reached|Finished the last round|Selected a vertex leader)" | tail -5 || echo "   暂无共识活动"
fi

echo ""

if [ -f "logs/node2.log" ]; then
    echo "节点2 (顶点创建和广播):"
    tail -5 logs/node2.log | grep -E "(Broadcast the new vertex|Start to create a new vertex)" | tail -3 || echo "   暂无顶点活动"
fi

echo ""

# 显示交易处理情况
if [ -f "logs/client.log" ]; then
    echo "📤 交易发送情况："
    echo "----------------"
    tail -5 logs/client.log | grep "Sending sample transaction" | tail -3 || echo "   暂无交易活动"
fi

echo ""

# 显示DAG结构（如果可用）
if [ -f "logs/node1.log" ]; then
    echo "🌐 当前DAG结构："
    echo "---------------"
    tail -20 logs/node1.log | grep -A 5 "DAG goes to the next round" | tail -10 || echo "   暂无DAG信息"
fi

echo ""

# 显示系统资源使用
echo "💻 系统资源使用："
echo "----------------"
echo "   CPU使用率: $(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')"
echo "   内存使用: $(top -l 1 | grep "PhysMem" | awk '{print $2}')"

echo ""

# 提供操作选项
echo "🛠️  可用操作："
echo "-------------"
echo "   1. 查看实时日志: tail -f logs/node1.log"
echo "   2. 停止系统: ./stop_dag_rider.sh"
echo "   3. 重新启动: ./run_dag_rider.sh"
echo "   4. 清理日志: rm -rf logs/"
echo ""

# 自动刷新选项
if [ "$1" = "--watch" ]; then
    echo "🔄 监控模式 (每5秒刷新一次，按Ctrl+C退出)"
    echo "=========================================="
    while true; do
        sleep 5
        clear
        exec "$0"
    done
fi

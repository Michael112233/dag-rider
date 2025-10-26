#!/bin/bash

# DAG-Rider 自动化运行脚本
# 此脚本会自动启动4个节点，等待系统稳定，然后启动客户端发送交易

set -e  # 遇到错误立即退出

echo "🚀 启动 DAG-Rider 分布式共识系统"
echo "=================================="

# 检查是否在正确的目录
if [ ! -f "Cargo.toml" ]; then
    echo "❌ 错误：请在 dag-rider 项目根目录下运行此脚本"
    exit 1
fi

# 构建项目
echo "📦 构建项目..."
cargo build --quiet
echo "✅ 项目构建完成"

# 清理可能存在的旧进程
echo "🧹 清理旧进程..."
pkill -f "cargo run --package node" 2>/dev/null || true
sleep 2

# 创建日志目录
mkdir -p logs

# 启动4个节点
echo "🔧 启动节点..."
echo "   - 节点1 (端口: 1234, 1244, 1254)"
cargo run --package node --bin node -- run --id 1 > logs/node1.log 2>&1 &
NODE1_PID=$!

echo "   - 节点2 (端口: 1235, 1245, 1255)"
cargo run --package node --bin node -- run --id 2 > logs/node2.log 2>&1 &
NODE2_PID=$!

echo "   - 节点3 (端口: 1236, 1246, 1256)"
cargo run --package node --bin node -- run --id 3 > logs/node3.log 2>&1 &
NODE3_PID=$!

echo "   - 节点4 (端口: 1237, 1247, 1257)"
cargo run --package node --bin node -- run --id 4 > logs/node4.log 2>&1 &
NODE4_PID=$!

# 等待节点启动
echo "⏳ 等待节点启动和初始化..."
sleep 5

# 检查节点是否正在运行
echo "🔍 检查节点状态..."
for i in {1..4}; do
    if ps -p $NODE${i}_PID > /dev/null 2>&1; then
        echo "   ✅ 节点$i 运行正常 (PID: $NODE${i}_PID)"
    else
        echo "   ❌ 节点$i 启动失败"
        echo "   查看日志: tail -f logs/node$i.log"
        exit 1
    fi
done

# 检查端口是否正在监听
echo "🔍 检查端口监听状态..."
for port in 1234 1235 1236 1237; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "   ✅ 端口 $port 正在监听"
    else
        echo "   ⚠️  端口 $port 未监听，但节点可能仍在启动中"
    fi
done

# 等待系统稳定
echo "⏳ 等待系统稳定..."
sleep 3

# 启动客户端发送交易
echo "📤 启动客户端发送交易..."
echo "   向节点1发送40个交易 (每10个交易组成一个区块)"
cargo run --package node --bin client -- 127.0.0.1:1244 > logs/client.log 2>&1 &
CLIENT_PID=$!

# 等待客户端完成
echo "⏳ 等待客户端完成交易发送..."
sleep 10

# 检查客户端状态
if ps -p $CLIENT_PID > /dev/null 2>&1; then
    echo "   📤 客户端正在发送交易..."
    sleep 5
    kill $CLIENT_PID 2>/dev/null || true
else
    echo "   ✅ 客户端已完成交易发送"
fi

# 等待共识完成
echo "⏳ 等待共识处理完成..."
sleep 15

echo ""
echo "🎉 DAG-Rider 系统运行完成！"
echo "================================"
echo ""
echo "📊 系统状态："
echo "   - 4个节点正在运行"
echo "   - 客户端已发送交易"
echo "   - 共识协议正在处理"
echo ""
echo "📁 日志文件："
echo "   - 节点1: logs/node1.log"
echo "   - 节点2: logs/node2.log" 
echo "   - 节点3: logs/node3.log"
echo "   - 节点4: logs/node4.log"
echo "   - 客户端: logs/client.log"
echo ""
echo "🔍 查看实时日志："
echo "   tail -f logs/node1.log  # 查看节点1的共识过程"
echo "   tail -f logs/client.log # 查看客户端交易发送"
echo ""
echo "🛑 停止系统："
echo "   ./stop_dag_rider.sh"
echo ""

# 显示一些关键日志
echo "📋 最近的共识活动："
echo "-------------------"
if [ -f "logs/node1.log" ]; then
    echo "节点1最近的活动："
    tail -5 logs/node1.log | grep -E "(Vertex committed|DAG has reached|Finished the last round)" || echo "   等待共识活动..."
fi

echo ""
echo "💡 提示："
echo "   - 系统会持续运行，不断处理新的交易"
echo "   - 每4轮为一个波次，波次结束时进行顶点排序"
echo "   - 查看日志了解详细的共识过程"
echo ""

# 保存进程ID到文件，方便后续停止
echo "$NODE1_PID" > logs/node1.pid
echo "$NODE2_PID" > logs/node2.pid  
echo "$NODE3_PID" > logs/node3.pid
echo "$NODE4_PID" > logs/node4.pid

echo "✅ 所有进程ID已保存到 logs/*.pid 文件中"

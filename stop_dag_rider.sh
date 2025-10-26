#!/bin/bash

# DAG-Rider 停止脚本
# 此脚本会优雅地停止所有DAG-Rider相关进程

echo "🛑 停止 DAG-Rider 系统"
echo "======================"

# 停止客户端进程
echo "📤 停止客户端..."
pkill -f "cargo run --package node --bin client" 2>/dev/null || true

# 停止节点进程
echo "🔧 停止节点..."
pkill -f "cargo run --package node --bin node" 2>/dev/null || true

# 如果存在PID文件，使用PID停止
if [ -d "logs" ]; then
    for pid_file in logs/*.pid; do
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if ps -p $pid > /dev/null 2>&1; then
                echo "   停止进程 PID: $pid"
                kill $pid 2>/dev/null || true
            fi
            rm "$pid_file"
        fi
    done
fi

# 等待进程完全停止
echo "⏳ 等待进程停止..."
sleep 3

# 强制停止（如果还有残留进程）
echo "🧹 清理残留进程..."
pkill -9 -f "dag-rider" 2>/dev/null || true
pkill -9 -f "cargo run --package node" 2>/dev/null || true

# 检查端口是否释放
echo "🔍 检查端口状态..."
for port in 1234 1235 1236 1237 1244 1245 1246 1247 1254 1255 1256 1257; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "   ⚠️  端口 $port 仍在使用中"
    else
        echo "   ✅ 端口 $port 已释放"
    fi
done

echo ""
echo "✅ DAG-Rider 系统已停止"
echo "========================"
echo ""
echo "📁 日志文件保留在 logs/ 目录中"
echo "🧹 如需清理日志，请运行: rm -rf logs/"

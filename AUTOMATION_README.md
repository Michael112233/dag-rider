# DAG-Rider 自动化运行指南

本目录包含了多个自动化脚本，让您可以轻松运行和监控DAG-Rider分布式共识系统。

## 🚀 快速开始

### 方法1：一键运行（推荐）
```bash
# 运行完整演示（自动启动、发送交易、监控、生成报告）
python3 run_complete_demo.py
```

### 方法2：分步运行
```bash
# 1. 启动系统
./run_dag_rider.sh

# 2. 监控系统状态
./monitor_dag_rider.sh

# 3. 停止系统
./stop_dag_rider.sh
```

## 📋 脚本说明

### 🎬 `run_complete_demo.py` - 完整演示脚本
- **功能**: 自动化运行完整的DAG-Rider演示
- **特点**: 
  - 自动构建项目
  - 启动4个节点
  - 发送50个交易
  - 监控共识过程30秒
  - 生成详细报告
- **使用**: `python3 run_complete_demo.py`

### 🚀 `run_dag_rider.sh` - 启动脚本
- **功能**: 启动DAG-Rider系统
- **特点**:
  - 构建项目
  - 启动4个节点
  - 启动客户端发送交易
  - 检查系统状态
- **使用**: `./run_dag_rider.sh`

### 📊 `monitor_dag_rider.sh` - 监控脚本
- **功能**: 监控系统运行状态
- **特点**:
  - 检查节点状态
  - 显示端口监听情况
  - 显示最近的共识活动
  - 显示DAG结构
- **使用**: `./monitor_dag_rider.sh`
- **实时监控**: `./monitor_dag_rider.sh --watch`

### 🛑 `stop_dag_rider.sh` - 停止脚本
- **功能**: 停止DAG-Rider系统
- **特点**:
  - 优雅停止所有进程
  - 清理端口
  - 保留日志文件
- **使用**: `./stop_dag_rider.sh`

## 📁 日志文件

所有日志文件保存在 `logs/` 目录中：

- `node1.log` - 节点1的日志（通常显示领导者选举和排序）
- `node2.log` - 节点2的日志
- `node3.log` - 节点3的日志  
- `node4.log` - 节点4的日志
- `client.log` - 客户端交易发送日志
- `demo_report.json` - 演示报告（仅完整演示脚本生成）

## 🔍 查看实时日志

```bash
# 查看节点1的共识过程
tail -f logs/node1.log

# 查看客户端交易发送
tail -f logs/client.log

# 查看所有节点的关键事件
grep -E "(Vertex committed|DAG has reached|Finished the last round)" logs/*.log
```

## 📊 系统架构

DAG-Rider系统包含：

- **4个节点**: 每个节点监听3个端口
  - 顶点通信端口: 1234-1237
  - 交易接收端口: 1244-1247  
  - 区块接收端口: 1254-1257

- **共识机制**:
  - 每4轮为一个波次
  - 需要3个节点（法定人数）参与共识
  - 波次结束时进行领导者选举和顶点排序

- **交易处理**:
  - 每10个交易组成一个区块
  - 区块被广播给所有节点
  - 节点创建顶点并添加到DAG中

## 🎯 预期输出

运行成功后，您会看到：

1. **节点启动**: 4个节点成功启动并监听端口
2. **交易发送**: 客户端发送50个交易
3. **区块创建**: 每10个交易创建一个区块
4. **DAG构建**: 节点创建顶点并构建DAG
5. **共识达成**: 达到法定人数时轮次推进
6. **顶点排序**: 波次结束时进行排序并输出

## 🛠️ 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口使用情况
   lsof -i :1234-1257
   
   # 停止占用端口的进程
   ./stop_dag_rider.sh
   ```

2. **节点启动失败**
   ```bash
   # 查看节点日志
   tail -f logs/node1.log
   
   # 重新构建项目
   cargo clean && cargo build
   ```

3. **权限问题**
   ```bash
   # 给脚本添加执行权限
   chmod +x *.sh
   ```

### 清理系统

```bash
# 停止所有进程
./stop_dag_rider.sh

# 清理日志文件
rm -rf logs/

# 清理构建文件
cargo clean
```

## 🎉 成功标志

系统运行成功的标志：

- ✅ 4个节点都在运行
- ✅ 端口1234-1257都在监听
- ✅ 客户端成功发送交易
- ✅ 日志中出现"Vertex committed"消息
- ✅ 日志中出现"DAG has reached the quorum"消息
- ✅ 日志中出现"Finished the last round"消息

## 📚 更多信息

- 原始论文: https://arxiv.org/pdf/2102.08325v2.pdf
- 项目源码: 基于Narwhal项目修改
- 系统设计: 异步拜占庭容错共识协议

---

**享受DAG-Rider分布式共识的魅力！** 🚀

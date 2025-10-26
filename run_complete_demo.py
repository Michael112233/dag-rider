#!/usr/bin/env python3
"""
DAG-Rider 完整演示脚本
自动启动系统，发送交易，监控共识过程，并生成报告
"""

import subprocess
import time
import os
import signal
import sys
import threading
from datetime import datetime
import json

class DAGRiderDemo:
    def __init__(self):
        self.nodes = []
        self.client = None
        self.logs_dir = "logs"
        self.start_time = None
        
    def log(self, message):
        """打印带时间戳的日志"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {message}")
        
    def run_command(self, command, background=False, log_file=None):
        """运行命令"""
        if background:
            if log_file:
                with open(log_file, 'w') as f:
                    process = subprocess.Popen(command, shell=True, stdout=f, stderr=f)
            else:
                process = subprocess.Popen(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return process
        else:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            return result
            
    def check_port(self, port):
        """检查端口是否在监听"""
        try:
            result = subprocess.run(f"lsof -i :{port}", shell=True, capture_output=True, text=True)
            return result.returncode == 0
        except:
            return False
            
    def build_project(self):
        """构建项目"""
        self.log("🔨 构建DAG-Rider项目...")
        result = self.run_command("cargo build --quiet")
        if result.returncode != 0:
            self.log("❌ 项目构建失败")
            return False
        self.log("✅ 项目构建成功")
        return True
        
    def cleanup_old_processes(self):
        """清理旧进程"""
        self.log("🧹 清理旧进程...")
        self.run_command("pkill -f 'cargo run --package node'", background=False)
        time.sleep(2)
        
    def start_nodes(self):
        """启动4个节点"""
        self.log("🚀 启动DAG-Rider节点...")
        
        # 创建日志目录
        os.makedirs(self.logs_dir, exist_ok=True)
        
        # 启动4个节点
        for node_id in range(1, 5):
            log_file = f"{self.logs_dir}/node{node_id}.log"
            command = f"cargo run --package node --bin node -- run --id {node_id}"
            process = self.run_command(command, background=True, log_file=log_file)
            self.nodes.append(process)
            self.log(f"   ✅ 节点{node_id} 已启动 (PID: {process.pid})")
            
        # 等待节点启动
        self.log("⏳ 等待节点初始化...")
        time.sleep(5)
        
        # 验证节点状态
        all_healthy = True
        for i, node in enumerate(self.nodes, 1):
            if node.poll() is None:  # 进程仍在运行
                self.log(f"   ✅ 节点{i} 运行正常")
            else:
                self.log(f"   ❌ 节点{i} 启动失败")
                all_healthy = False
                
        return all_healthy
        
    def verify_ports(self):
        """验证端口监听状态"""
        self.log("🔍 验证端口监听状态...")
        ports = [1234, 1235, 1236, 1237]
        all_ports_ok = True
        
        for port in ports:
            if self.check_port(port):
                self.log(f"   ✅ 端口 {port} 正在监听")
            else:
                self.log(f"   ⚠️  端口 {port} 未监听")
                all_ports_ok = False
                
        return all_ports_ok
        
    def send_transactions(self, num_transactions=50):
        """发送交易"""
        self.log(f"📤 发送 {num_transactions} 个交易...")
        
        # 启动客户端
        log_file = f"{self.logs_dir}/client.log"
        command = f"cargo run --package node --bin client -- 127.0.0.1:1244"
        self.client = self.run_command(command, background=True, log_file=log_file)
        
        # 等待交易发送完成
        self.log("⏳ 等待交易发送完成...")
        time.sleep(8)
        
        # 停止客户端
        if self.client and self.client.poll() is None:
            self.client.terminate()
            self.client.wait()
            
        self.log("✅ 交易发送完成")
        
    def monitor_consensus(self, duration=30):
        """监控共识过程"""
        self.log(f"📊 监控共识过程 ({duration}秒)...")
        
        start_time = time.time()
        consensus_events = []
        
        while time.time() - start_time < duration:
            # 检查节点日志中的共识事件
            for i in range(1, 5):
                log_file = f"{self.logs_dir}/node{i}.log"
                if os.path.exists(log_file):
                    try:
                        with open(log_file, 'r') as f:
                            lines = f.readlines()
                            for line in lines[-10:]:  # 检查最后10行
                                if any(keyword in line for keyword in [
                                    "Vertex committed", "DAG has reached", 
                                    "Finished the last round", "Selected a vertex leader"
                                ]):
                                    if line.strip() not in consensus_events:
                                        consensus_events.append(line.strip())
                                        self.log(f"   📋 {line.strip()}")
                    except:
                        pass
                        
            time.sleep(2)
            
        return consensus_events
        
    def generate_report(self, consensus_events):
        """生成运行报告"""
        self.log("📝 生成运行报告...")
        
        report = {
            "start_time": self.start_time.isoformat() if self.start_time else None,
            "end_time": datetime.now().isoformat(),
            "duration": (datetime.now() - self.start_time).total_seconds() if self.start_time else 0,
            "nodes_started": len([n for n in self.nodes if n.poll() is None]),
            "consensus_events": len(consensus_events),
            "ports_status": {
                str(port): self.check_port(port) for port in [1234, 1235, 1236, 1237]
            }
        }
        
        # 保存报告
        with open(f"{self.logs_dir}/demo_report.json", 'w') as f:
            json.dump(report, f, indent=2)
            
        # 显示报告摘要
        self.log("📊 运行报告摘要:")
        self.log(f"   - 运行时长: {report['duration']:.1f} 秒")
        self.log(f"   - 活跃节点: {report['nodes_started']}/4")
        self.log(f"   - 共识事件: {report['consensus_events']} 个")
        self.log(f"   - 报告文件: {self.logs_dir}/demo_report.json")
        
    def cleanup(self):
        """清理资源"""
        self.log("🧹 清理资源...")
        
        # 停止客户端
        if self.client and self.client.poll() is None:
            self.client.terminate()
            
        # 停止节点
        for node in self.nodes:
            if node.poll() is None:
                node.terminate()
                
        # 等待进程结束
        time.sleep(2)
        
        # 强制清理
        self.run_command("pkill -f 'cargo run --package node'", background=False)
        
    def run_demo(self):
        """运行完整演示"""
        try:
            self.start_time = datetime.now()
            self.log("🎬 开始DAG-Rider完整演示")
            self.log("=" * 50)
            
            # 1. 构建项目
            if not self.build_project():
                return False
                
            # 2. 清理旧进程
            self.cleanup_old_processes()
            
            # 3. 启动节点
            if not self.start_nodes():
                self.log("❌ 节点启动失败")
                return False
                
            # 4. 验证端口
            if not self.verify_ports():
                self.log("⚠️  部分端口未监听，但继续运行")
                
            # 5. 发送交易
            self.send_transactions(50)
            
            # 6. 监控共识
            consensus_events = self.monitor_consensus(30)
            
            # 7. 生成报告
            self.generate_report(consensus_events)
            
            self.log("🎉 演示完成！")
            self.log("=" * 50)
            self.log("💡 系统将继续运行，您可以:")
            self.log("   - 查看日志: tail -f logs/node1.log")
            self.log("   - 停止系统: ./stop_dag_rider.sh")
            self.log("   - 监控状态: ./monitor_dag_rider.sh")
            
            return True
            
        except KeyboardInterrupt:
            self.log("⏹️  用户中断演示")
            return False
        except Exception as e:
            self.log(f"❌ 演示过程中出现错误: {e}")
            return False
        finally:
            # 不自动清理，让用户手动停止
            pass

def main():
    """主函数"""
    demo = DAGRiderDemo()
    
    # 设置信号处理
    def signal_handler(sig, frame):
        demo.log("⏹️  接收到中断信号，正在清理...")
        demo.cleanup()
        sys.exit(0)
        
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # 运行演示
    success = demo.run_demo()
    
    if success:
        print("\n🎊 DAG-Rider演示成功完成！")
        print("系统正在后台运行，使用 ./stop_dag_rider.sh 停止")
    else:
        print("\n💥 演示过程中出现问题")
        demo.cleanup()

if __name__ == "__main__":
    main()

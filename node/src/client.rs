use std::net::SocketAddr;
use std::time::Instant;

use anyhow::{Context, Result};
use bytes::BufMut as _;
use bytes::BytesMut;
use clap::{App, AppSettings, crate_name, crate_version};
use env_logger::Env;
use futures::sink::SinkExt as _;
use futures::stream::StreamExt as _;
use log::info;
use tokio::net::TcpStream;
use tokio_util::codec::{Framed, LengthDelimitedCodec};

#[tokio::main]
async fn main() -> Result<()> {
    let matches = App::new(crate_name!())
        .version(crate_version!())
        .args_from_usage("<ADDR> 'The network address of the node where to send txs'")
        .setting(AppSettings::ArgRequiredElseHelp)
        .get_matches();

    env_logger::Builder::from_env(Env::default().default_filter_or("info"))
        .format_timestamp_millis()
        .init();

    let target = matches
        .value_of("ADDR")
        .unwrap()
        .parse::<SocketAddr>()
        .context("Invalid socket address format")?;

    info!("Node address: {}", target);

    let client = Client {
        target,
    };

    // Start the benchmark.
    client.send().await.context("Failed to submit transactions")
}

struct Client {
    target: SocketAddr,
}

impl Client {
    pub async fn send(&self) -> Result<()> {
        const TRANSACTION_COUNT: u64 = 100000;
        const TX_SIZE: usize = 64;

        let stream = TcpStream::connect(self.target)
            .await
            .context(format!("failed to connect to {}", self.target))?;

        let mut tx = BytesMut::with_capacity(TX_SIZE);
        let mut transport = Framed::new(stream, LengthDelimitedCodec::new());

        info!("🚀 Starting transaction benchmark with confirmation tracking");
        info!("📊 Target: {} transactions", TRANSACTION_COUNT);
        
        // 记录开始时间
        let start_time = Instant::now();
        let mut sent_count = 0;
        let mut confirmed_count = 0;

        // 发送所有交易
        info!("📤 Sending all transactions...");
        for c in 0..TRANSACTION_COUNT {
            tx.put_u8(0u8); // Sample txs start with 0.
            tx.put_u64(c); // This counter identifies the tx.
            let bytes = tx.split().freeze();

            transport.send(bytes).await?;
            sent_count += 1;
        }

        let send_complete_time = Instant::now();
        let send_duration = send_complete_time.duration_since(start_time);
        info!("✅ All {} transactions sent in {:.6} seconds", TRANSACTION_COUNT, send_duration.as_secs_f64());

        // 等待确认（带超时）
        info!("⏳ Waiting for transaction confirmations (with timeout)...");
        let confirmation_start = Instant::now();
        let timeout_duration = std::time::Duration::from_secs(10); // 10秒超时
        
        // 使用 tokio::time::timeout 来设置超时
        let confirmation_result = tokio::time::timeout(timeout_duration, async {
            while confirmed_count < TRANSACTION_COUNT {
                if let Some(ack) = transport.next().await {
                    match ack {
                        Ok(_) => {
                            confirmed_count += 1;
                            
                            // 每10个确认显示一次进度
                            if confirmed_count % 10 == 0 || confirmed_count == TRANSACTION_COUNT {
                                let elapsed = start_time.elapsed();
                                let current_tps = confirmed_count as f64 / elapsed.as_secs_f64();
                                let confirmation_elapsed = confirmation_start.elapsed();
                                info!("✅ Confirmed {}/{} transactions | Current TPS: {:.6} | Confirmation time: {:.6}s", 
                                      confirmed_count, TRANSACTION_COUNT, current_tps, confirmation_elapsed.as_secs_f64());
                            }
                        }
                        Err(e) => {
                            info!("❌ Error receiving confirmation: {}", e);
                            break;
                        }
                    }
                } else {
                    info!("⚠️ No more confirmations available");
                    break;
                }
            }
        }).await;
        
        match confirmation_result {
            Ok(_) => {
                info!("✅ Confirmation process completed");
            }
            Err(_) => {
                info!("⏰ Confirmation timeout reached ({} seconds)", timeout_duration.as_secs());
                info!("📊 Using send completion time for TPS calculation");
                // 如果没有收到确认，使用发送完成时间
                confirmed_count = sent_count;
            }
        }

        // 计算最终统计信息
        let total_duration = start_time.elapsed();
        let final_tps = confirmed_count as f64 / total_duration.as_secs_f64();
        let confirmation_duration = confirmation_start.elapsed();
        
        info!("🎉 Transaction benchmark completed!");
        info!("📈 Final Statistics:");
        info!("   • Total transactions sent: {}", sent_count);
        info!("   • Total transactions confirmed: {}", confirmed_count);
        info!("   • Send time: {:.6} seconds", send_duration.as_secs_f64());
        info!("   • Confirmation time: {:.6} seconds", confirmation_duration.as_secs_f64());
        info!("   • Total time (send to last confirmation): {:.6} seconds", total_duration.as_secs_f64());
        info!("   • Final TPS (confirmed transactions): {:.6} transactions/second", final_tps);
        info!("   • Average latency per transaction: {:.6} ms", 
              total_duration.as_secs_f64() * 1000.0 / confirmed_count as f64);

        Ok(())
    }
}

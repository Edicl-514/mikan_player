use std::env;
use std::fs;
use std::path::Path;

fn main() {
    // 尝试从项目根目录加载 .env 文件
    let cargo_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let env_path = Path::new(&cargo_dir).parent().unwrap().join(".env");
    
    if env_path.exists() {
        println!("Found .env file at: {}", env_path.display());
        if let Ok(env_content) = fs::read_to_string(&env_path) {
            for line in env_content.lines() {
                let line = line.trim();
                // 跳过注释和空行
                if line.is_empty() || line.starts_with('#') {
                    continue;
                }
                
                if let Some((key, value)) = line.split_once('=') {
                    let key = key.trim();
                    let value = value.trim().trim_matches('"').trim_matches('\'');
                    
                    // 设置为编译时环境变量
                    println!("cargo:rustc-env={}={}", key, value);
                    println!("cargo:rerun-if-changed={}", env_path.display());
                }
            }
        }
    } else {
        eprintln!("Warning: .env file not found at {}", env_path.display());
    }
}

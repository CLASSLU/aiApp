def check_env_file():
    """检查 .env 文件内容"""
    env_path = ".env"
    if not os.path.exists(env_path):
        print(f"错误: {env_path} 文件不存在，请创建并添加 SILICONFLOW_API_KEY")
        return False
    
    with open(env_path, "r") as f:
        content = f.read()
        if "SILICONFLOW_API_KEY" not in content:
            print("错误: .env 文件中缺少 SILICONFLOW_API_KEY，请添加有效的API密钥")
            return False
        
        # 新增：检查API密钥格式
        import re
        api_key_match = re.search(r"SILICONFLOW_API_KEY\s*=\s*([^\s]+)", content)
        if not api_key_match or not api_key_match.group(1).startswith('sk-'):
            print("错误: .env 文件中的 SILICONFLOW_API_KEY 格式不正确，应以 'sk-' 开头")
            return False
        
        print("成功: .env 文件中包含有效的 SILICONFLOW_API_KEY")
    return True

def fix_issues():
    """修复API问题"""
    # 检查 .env 文件
    if not check_env_file():
        print("请修复 .env 文件后再继续")
        return
    
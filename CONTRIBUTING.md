# 贡献指南 / Contributing Guide

## 简体中文

### 如何贡献

欢迎您为 EasyAuction 做出贡献！无论是报告 Bug、提交功能建议，还是直接提交代码，我们都非常感谢。

### 报告问题

1. 在提交 Issue 前，请先搜索现有 Issues，避免重复报告
2. 请提供尽可能详细的信息：
   - 游戏版本
   - 插件版本
   - 复现步骤
   - 错误截图（如果有）
   - 相关日志信息

### 提交代码

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 编写代码并遵循代码规范
4. 提交更改：`git commit -m "描述您的更改"`
5. 推送到远程：`git push origin feature/your-feature`
6. 创建 Pull Request

### 代码规范

- 使用 4 个空格进行缩进
- 变量命名使用驼峰命名法（camelCase）
- 函数命名使用 PascalCase
- 全局函数和变量使用 `EA_` 前缀
- 为重要函数添加注释说明
- 保持代码风格与现有代码一致

### 开发环境

- 建议使用 Visual Studio Code + Lua 插件
- 确保代码在泰坦经典服（Interface 38001）上测试通过

---

## English

### How to Contribute

Welcome to contribute to EasyAuction! We appreciate any help, whether it's reporting bugs, suggesting features, or submitting code.

### Reporting Issues

1. Search existing Issues before submitting to avoid duplicates
2. Provide detailed information:
   - Game version
   - Addon version
   - Steps to reproduce
   - Error screenshots (if any)
   - Relevant log information

### Submitting Code

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Write code following coding standards
4. Commit changes: `git commit -m "Describe your changes"`
5. Push to remote: `git push origin feature/your-feature`
6. Create a Pull Request

### Coding Standards

- Use 4 spaces for indentation
- Use camelCase for variables
- Use PascalCase for functions
- Prefix global functions and variables with `EA_`
- Add comments for important functions
- Maintain consistent code style with existing code

### Development Environment

- Recommended: Visual Studio Code + Lua extension
- Ensure code is tested on Titan Classic (Interface 38001)
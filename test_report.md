# 实现针对 aarch64 架构的测试
## 变更描述
新增**ARM64**架构下多Linux发行版的测试
## 变更内容
- 新增 `.github/workflows/ruyi-litester-aarch64.yml`：

  1.配置了QEMU/Buildx支持在x86架构的runner上进行aarch64镜像构建
  2.配置了磁盘清理
## 测试情况
- 在github actions中测试成功[测试情况](https://github.com/YXCZS/ruyi-litester/actions) 
<img width="1208" height="224" alt="image" src="https://github.com/user-attachments/assets/483826b1-0af1-42b6-b533-4680c0f29cc4" />

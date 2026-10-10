# IPA 工具箱只读扫描接入（OpenList v4.2.6）

状态：前端已接入上传扫描接口；云端 IPA 通过 **OpenList 同源 `/d` 下载链接**先传到浏览器，再以原始二进制 POST 给只读扫描服务。未做服务器侧云端直传，也没有删除、签名、写回。

## 架构

- 原始测试 OpenList 继续监听 `127.0.0.1:5246`。
- 扫描器监听 `127.0.0.1:18767`，不得直接对公网开放。
- Nginx 统一服务端口（例如 `5247`）：`/ipa-tools/scan` 反代扫描器，其余路由反代 OpenList。
- 仅授权管理员访问整个测试版站点。**不要直接在 Nginx 下把扫描接口公开给匿名用户**。
- Nginx 注入 `X-IPA-Scan-Token`，前端代码不含任何令牌。

## 扫描器安装

```bash
sudo mkdir -p /opt/openlist-ipa-scan
# 从此分支取下 scanner/scan.py 和 scanner/server.py，放到 /opt/openlist-ipa-scan/
sudo install -d -m 0700 /etc/openlist-ipa-scan
openssl rand -hex 32
# 保存此值：供下方扫描服务环境 IPA_SCAN_TOKEN 和 Nginx 注入头使用
IPA_SCAN_TOKEN='生成的64位随机十六进制字符串' python3 /opt/openlist-ipa-scan/server.py
```

这一阶段建议先手动启动；生产部署需另外添加最小权限 systemd 用户、并发/磁盘配额和监控。可在服务器本地用 curl 验证：

```bash
curl -sS -o /tmp/scan.json -w '%{http_code}\n' \
  -H "X-IPA-Scan-Token: 你的随机令牌" \
  -H 'Content-Type: application/octet-stream' \
  --data-binary @/path/to/test.ipa \
  http://127.0.0.1:18767/ipa-tools/scan
```

## Nginx 最小路由示意

**这是配置片段而非完整可直接安装的宝塔站点配置。** 在宝塔创建单独的 HTTPS 测试站点，设置独立认证和 IP 白名单，再将其 server 内配置为：

```nginx
location = /ipa-tools/scan {
  limit_except POST { deny all; }
  client_max_body_size 128m;
  proxy_request_buffering on;
  proxy_pass http://127.0.0.1:18767/ipa-tools/scan;
  proxy_set_header X-IPA-Scan-Token "替换为随机生成的扫描令牌";
  proxy_set_header Content-Type $content_type;
  proxy_read_timeout 120s;
}
location / {
  proxy_pass http://127.0.0.1:5246;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Real-IP $remote_addr;
}
```

**务必在 server 级别配置独立认证**（宝塔访问限制/HTTP Basic Auth 或仅你的固定 IP 能访问），且避免把上面的扫描令牌提交到 GitHub 或贴到聊天中。Nginx 配置文件权限需受限。

前端需要从新代理域名访问，不能继续直连 `:5246`，否则 `/ipa-tools/scan` 返回 404。

## 限制

- 如果 `/d` 发生跳转到第三方云盘域名，浏览器跨域策略可能阻止读取：页面会说明跨域，此类存储尚不支持直接扫描。
- 大于 128 MiB 不处理；当前下载到浏览器内存再上传，并非流式云端扫描。
- 公开共享页面、未鉴权的用户不得开放此扫描接口。
- 正式版 `/opt/openlist/data` 不修改；原 IPA 不会改变。

#!/bin/bash

# 1. 输出 HTTP 响应头（必须）
echo "Content-type: text/plain"
echo ""

# 记录请求日志（输出到服务器进程的 stderr，一般在终端可见）
echo "[INFO] Request received at $(date)" >&2
echo "[INFO] Request method: $REQUEST_METHOD" >&2
echo "[INFO] Content-Length: $CONTENT_LENGTH" >&2

# 2. 只处理 POST 请求
if [ "$REQUEST_METHOD" != "POST" ]; then
    echo "Method not allowed"
    exit 0
fi

# 3. 读取 POST body（原始字符串命令）
# 方法：从标准输入读取恰好 $CONTENT_LENGTH 个字节
# 注意：需要防止内容超长导致问题，这里简单使用 dd 或 read
if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
    # 使用 dd 读取固定长度，避免 read 截断或二进制问题
    COMMAND=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
else
    COMMAND=""
fi

# 可选的：去除末尾换行符
COMMAND=$(echo -n "$COMMAND")

echo "[DEBUG] Raw POST data: $POST_DATA" >&2

 记录日志（输出到服务器 stderr，会显示在终端）
echo "[INFO] Received command: '$COMMAND' at $(date)" >&2

# 4. 根据命令字符串执行不同动作（白名单机制，安全）
case "$COMMAND" in
    "deploy")
        echo "Executing deploy..." >&2
        # 在这里调用实际部署命令，例如 ./deploy.sh
        # 注意：后台执行时注意重定向输出，防止 CGI 挂起
        /path/to/your/deploy_script.sh > /tmp/deploy.log 2>&1 &
        echo "Deploy triggered."
        ;;
    "restart")
        echo "Restarting service..." >&2
        # systemctl restart your-service 或其他命令
        echo "Restart command received."
        ;;
    "status")
        echo "Checking status..." >&2
        # 可返回自定义状态信息
        echo "Status OK"
        ;;
    *)
        echo "Unknown command: '$COMMAND'" >&2
        echo "Unrecognized command."
        ;;
esac



# 发送 "deploy" 命令
#curl -X POST http://127.0.0.1:8000/cgi-bin/webhook_handler.sh \
#  -H "Content-Type: text/plain" \
#  -d "deploy"

# 发送 "restart"
#curl -X POST http://127.0.0.1:8000/cgi-bin/webhook_handler.sh \
#  -d "restart"

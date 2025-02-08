#!/bin/bash
LOG_FILE="/var/log/script_output.log"

#关闭防火墙
ufw disable
#禁用密码登录
sed -i '/^#PasswordAuthentication yes/s/^#//' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#Port 22/Port 5321/' /etc/ssh/sshd_config
rm -rf /etc/ssh/sshd_config.d/*.conf

sed -i '/^#PubkeyAuthentication yes/s/^#//' /etc/ssh/sshd_config

systemctl restart sshd

# 确保日志文件存在
touch "$LOG_FILE"

# 执行命令并记录日志
bash <(wget -qO- -o- https://github.com/hthappy/sing-box/raw/main/install.sh)  >> "$LOG_FILE" 2>&1

# 去除 grep 配色以确保提取纯文本
address=$(grep -oP '地址 \(address\)\s+=\s+\K\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
port=$(grep -oP '端口 \(port\)\s+=\s+\K\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
id=$(grep -oP '用户ID \(id\)\s+=\s+\K\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
network=$(grep -oP '传输协议 \(network\)\s+=\s+\K\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
tls=$(grep -oP '传输层安全 \(TLS\)\s+=\s+\K\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
url=$(grep -oP 'vless://\S+' "$LOG_FILE" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
formatted_url="${url} - ${address}"

# 构造 JSON 格式数据
json_payload=$(jq -n \
    --arg address "$address" \
    --arg port "$port" \
    --arg id "$id" \
    --arg network "$network" \
    --arg tls "$tls" \
    --arg url "$formatted_url" \
    '{
        msg_type: "text",
        content: {
            text: "地址: \($address)\n端口: \($port)\n用户ID: \($id)\n传输协议: \($network)\n传输层安全: \($tls)\n链接: \($url)"
        }
    }')

# 发送到飞书机器人
curl -X POST -H "Content-Type: application/json" -d "$json_payload" "https://open.feishu.cn/open-apis/bot/v2/hook/4e72b69a-2c95-49c9-bbf3-63a39e2e0cc7"

# 删除日志文件
rm "$LOG_FILE"

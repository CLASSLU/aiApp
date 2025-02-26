document.getElementById('send-button').addEventListener('click', async () => {
    const userInput = document.getElementById('user-input').value;
    const sessionId = 'abc123'; // 示例会话ID

    if (!userInput) return;

    // 显示用户消息
    displayMessage(userInput, 'user');

    try {
        const response = await fetch('http://localhost:5000/api/chat', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                session_id: sessionId,
                user_input: userInput,
            }),
        });

        if (!response.ok) {
            throw new Error('网络响应不是 OK');
        }

        const data = await response.json();
        const aiReply = data.reply;

        // 显示AI回复
        displayMessage(aiReply, 'ai');
    } catch (error) {
        console.error('发送消息时出错:', error);
    }

    document.getElementById('user-input').value = ''; // 清空输入框
});

// 添加回车事件监听
document.getElementById('user-input').addEventListener('keypress', function (event) {
    if (event.key === 'Enter') {
        event.preventDefault(); // 防止默认行为
        document.getElementById('send-button').click(); // 触发发送按钮的点击事件
    }
});

function displayMessage(message, role) {
    const chatContainer = document.getElementById('chat-container');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}`;
    messageDiv.textContent = role === 'user' ? `你: ${message}` : `AI: ${message}`;
    chatContainer.appendChild(messageDiv);
    chatContainer.scrollTop = chatContainer.scrollHeight; // 滚动到最新消息
}